//
//  MjolnirController.swift
//  VaavudSDK
//
//  Created by Marco Di Peco on 01/03/2020.
//  Copyright © 2020 Marco Di Peco All rights reserved.
//

import Foundation
import CoreMotion
import Combine

@available(iOS 13.0, *)
public class MjolnirController {
    
    public static let fq40FFTLenght = 64
    public static let fq40FFTDataLenght = 50
    public static let standardFrequencyStart = 0.238
    public static let standardFrequencyFactor = 1.07
    public static let fftPeakMagnitudeMinForValid = 2.5
    
    //MARK: - Properties
    
    fileprivate var motionController: MotionController
    fileprivate var magneticController: MagneticFieldController
    fileprivate var signalAnalyzer: SignalAnalyzer
    
    fileprivate var magneticReadings = [MagneticSample]()
    fileprivate var xResults = [Double]()
    fileprivate var yResults = [Double]()
    fileprivate var zResults = [Double]()
    
    fileprivate var isDynamicValid: Bool {
        motionController.isDynamicValid
    }
    
    fileprivate var sumOfValidMeasurements = 0.0
    
    var average: Double {
        sumOfValidMeasurements / Double(windData.count)
    }
    
    public var sampleFrequency: Double {
        
        guard let lastTime = magneticReadings.last?.time else { return 0 }
        
        let sampleFrequency = Double(magneticReadings.count) / lastTime
        
        return sampleFrequency;
    }
    
    fileprivate(set) var maxWindSpeed: Double = 0
    
    ///isValidPercent start at 50% valid
    fileprivate var percentForValidity = 50
    fileprivate var isValidCurrentStatus = false
    
    fileprivate var windData = [WindSample]()
    
    private let windPublisher: PassthroughSubject<WindSample, Never>
    public var publisher: AnyPublisher<WindSample, Never>
    
    fileprivate var magneticSubscriber: AnyCancellable?
    
    //MARK: - Lifecycle
    
    public init() {
        self.motionController = MotionController()
        self.magneticController = MagneticFieldController()
        self.signalAnalyzer = SignalAnalyzer(fftLength: MjolnirController.fq40FFTLenght,
                                             fftDataLength: MjolnirController.fq40FFTDataLenght)!
        
        windPublisher = PassthroughSubject<WindSample, Never>()
        publisher = windPublisher.eraseToAnyPublisher()
    }
    
    public func start() {
        
        magneticController.start()
        motionController.start()
        
        magneticSubscriber = magneticController.publisher.sink(receiveCompletion: { error in
            print(".sink() received the completion", String(describing: error))
        }, receiveValue: { magneticSample in
            self.parseSample(magneticSample)
        })
    }
    
    public func stop() {
        magneticController.stop()
        motionController.stop()
    }
    
    //MARK: - Parsing
    
    func parseSample(_ sample: MagneticSample) {
        
        self.magneticReadings.append(sample)
        
        guard magneticReadings.count > MjolnirController.fq40FFTDataLenght else {
            return
        }
        
        guard self.magneticReadings.count % 3 == 0 else {
            return
        }
        
        let average = self.runAnalysys()
        
        // use quadratic interpolation to find peak
        // Calculate max peak
        var maxPeak: Double = 0.0
        var alpha: Double = 0.0
        var beta: Double = 0.0
        var gamma: Double = 0.0
        var p: Double = 0.0
        var dominantFrequency: Double = 0.0
        var frequencyMagnitude: Double = 0.0
        
        var maxBin = 0
        
        for i in 0 ..< MjolnirController.fq40FFTLenght / 2 {
            
            if average[i] > maxPeak {
                maxBin = i
                maxPeak = average[i]
            }
        }
        
        if (maxBin > 0) && (maxBin < (MjolnirController.fq40FFTLenght / 2) - 1) {
            alpha = average[maxBin - 1]
            beta = average[maxBin]
            gamma = average[maxBin + 1]
            
            p = (alpha - gamma) / (2 * (alpha - (2 * beta) + gamma))
            
            dominantFrequency  = (Double(maxBin) + p) * self.sampleFrequency / Double(MjolnirController.fq40FFTLenght)
            frequencyMagnitude = beta - 1/4 * (alpha - gamma) * p
            
        } else {
            dominantFrequency = 0;
            frequencyMagnitude = 0;
        }
        
        // windspeed
        
        let windSpeed = dominantFrequency.toWindSpeed()
        let windSpeedTime = self.magneticReadings.last?.time ?? 0.0
        
        var fftIsValid = false
        
        if frequencyMagnitude > MjolnirController.fftPeakMagnitudeMinForValid {
            fftIsValid = true
            
            self.sumOfValidMeasurements += windSpeed
            if windSpeed > self.maxWindSpeed {
                self.maxWindSpeed = windSpeed
            }
        } else {
            fftIsValid = false
        }
        
        self.isValidCurrentStatus = self.computeValidity(for: fftIsValid)
        
        let windAverage = self.sumOfValidMeasurements / (Double(self.windData.count) + 1)
        
        let sample = WindSample(speed: windSpeed,
                                max: self.maxWindSpeed,
                                average: windAverage,
                                time: windSpeedTime,
                                isValid: self.isValidCurrentStatus)
        
        self.windData.append(sample)
        self.windPublisher.send(sample)
    }
    
    //MARK: - Analysis
    
    fileprivate func runAnalysys() -> [Double] {
        
        let modulus = magneticReadings.count % 9 / 3
        
        var start = 0
        var end = magneticReadings.count - 1
        
        if magneticReadings.count > MjolnirController.fq40FFTDataLenght {
            start = magneticReadings.count - MjolnirController.fq40FFTDataLenght
            end = MjolnirController.fq40FFTDataLenght
        }
        
        let subArrayRange = start ..< end
        
        let subReadings = magneticReadings[subArrayRange]
        
        switch modulus {
            case 0:
                
                let xReadings = subReadings.map { $0.field.x }
                xResults = signalAnalyzer.perfomAnalysis(on: xReadings)
                
            case 1:
                let yReadings = subReadings.map { $0.field.y }
                yResults = signalAnalyzer.perfomAnalysis(on: yReadings)
            case 2:
                let zReadings = subReadings.map { $0.field.z }
                zResults = signalAnalyzer.perfomAnalysis(on: zReadings)
                
            default:
                print("You should not be here!")
                return []
        }
        
        // create average
        let resultArrayLength = MjolnirController.fq40FFTLenght / 2
        
        var average = [Double]()
        
        for i in 0 ..< resultArrayLength {
            
            let mean = (xResults[i] + yResults[i] + zResults[i]) / 3;
            
            average.append(mean)
        }
        
        return average
    }
    
    fileprivate func computeValidity(for fftIsValid: Bool) -> Bool {
        
        var isValid = false
            
        if fftIsValid == false {
            percentForValidity = 0
        }
        
        if fftIsValid && motionController.isDynamicValid {
            percentForValidity += 8
        } else {
            percentForValidity -= 8
        }
        
        if percentForValidity > 100 {
            percentForValidity = 100
            isValid = true
        }
        
        if percentForValidity < 0 {
            percentForValidity = 0
            isValid = false
        }
        
        return isValid
    }

}

extension Double {
    
    public func toWindSpeed() -> Double {
        
        // Based on 09.07.2013 Windtunnel test. Parametes can be found in windTunnelAnalysis_9_07_2013.xlsx
        // Corrected base on data from Windtunnel test Experiment26Aug2013Data.xlsx
        var windSpeed = MjolnirController.standardFrequencyFactor * self + MjolnirController.standardFrequencyStart
        
        if self > 17.65 && self < 28.87 {
            windSpeed = windSpeed + -0.068387 * pow((self - 23.2667), 2) + 2.153493
        }
        
        return windSpeed
    }
}
