//
//  MagneticFieldController.swift
//  VaavudSDK
//
//  Created by Marco Di Peco on 01/03/2020.
//  Copyright © 2020 Marco Di Peco. All rights reserved.
//

import Foundation
import CoreMotion
import QuartzCore
import Combine

enum MagneticError: Error {
    case notAvailable
    case generic
}

@available(iOS 13.0, *)
public class MagneticFieldController {
    
    static let sampleFrequency = 100
    
    //MARK: - Properties
    
    private let magneticPublisher: PassthroughSubject<MagneticSample, Error>
    public var publisher: AnyPublisher<MagneticSample, Error>
    
    fileprivate let motionManager = CMMotionManager()
    fileprivate var operationQueue = OperationQueue.current
    fileprivate var startTime = CACurrentMediaTime()
    
    //MARK: - Lifecycle
    
    init() {
        magneticPublisher = PassthroughSubject<MagneticSample, Error>()
        publisher = magneticPublisher.eraseToAnyPublisher()
    }
    
    public func start() {
        startMagneticFieldSensor()
    }
    
    public func stop() {
        motionManager.stopMagnetometerUpdates()
    }
    
    fileprivate func startMagneticFieldSensor() {
        
        guard motionManager.isMagnetometerAvailable else {
            magneticPublisher.send(completion: Subscribers.Completion.failure(MagneticError.notAvailable))
            return
        }
        
        guard let queue = operationQueue else {
            magneticPublisher.send(completion: Subscribers.Completion.failure(MagneticError.generic))
            return
        }
        
        motionManager.magnetometerUpdateInterval = TimeInterval(1 / MagneticFieldController.sampleFrequency)
        
        motionManager.startMagnetometerUpdates(to: queue) { magnetometerData, error in
            
            guard error == nil else {
                return
            }
            
            guard let data = magnetometerData else {
                return
            }
            
            let time = CACurrentMediaTime() - self.startTime
            
            self.magneticPublisher.send(MagneticSample(field: data.magneticField, time: time))
        }
    }
}
