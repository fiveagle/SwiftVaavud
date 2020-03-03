//
//  MagneticFieldController.swift
//  VaavudSDK
//
//  Created by Marco Di Peco on 01/03/2020.
//  Copyright © 2020 Marco Di Peco. All rights reserved.
//

import Foundation
import CoreMotion

public class MagneticFieldController: ObservableObject {
    
    static let sampleFrequency = 100
    
    //MARK: - Properties
    
    @Published var magneticReading: (Double, CMMagneticField)!
    
    fileprivate let motionManager = CMMotionManager()
    fileprivate var operationQueue = OperationQueue.current
    fileprivate var startTime = CACurrentMediaTime()
    
    //MARK: - Lifecycle
    
    func start() {
        startMagneticFieldSensor()
    }
    
    func stop() {
        motionManager.stopMagnetometerUpdates()
    }
    
    fileprivate func startMagneticFieldSensor() {
        
        guard motionManager.isMagnetometerAvailable else {
            return
        }
        
        guard let queue = operationQueue else {
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
            self.magneticReading = (time, data.magneticField)
        }
    }
}
