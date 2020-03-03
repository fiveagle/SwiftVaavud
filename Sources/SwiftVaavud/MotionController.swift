//
//  MotionController.swift
//  VaavudSDK
//
//  Created by Marco Di Peco on 01/03/2020.
//  Copyright © 2020 Marco Di Peco. All rights reserved.
//

import Foundation
import CoreMotion

public class MotionController: ObservableObject {
    
    //MARK: - Constants
    static let accAndGyroSampleFrequency = 5
    static let orientationDeviationMaxForValid = 0.63 // rad  (36) degrees
    static let accelerationMaxForValid =  0.4 // g acc/(9.82 m/s^2)
    static let angularVelocityMaxForValid =  0.4 // rad/s (maybe deg/s or another unit)
    
    //MARK: - Validity properties
    fileprivate var accelerationIsValid: Bool = false
    fileprivate var orientationIsValid: Bool = false
    fileprivate var angularVeclocityIsValid: Bool = false
    
    @Published var isDynamicValid: Bool = false
    
    //MARK: - Properties
    fileprivate let motionManager = CMMotionManager()
    
    fileprivate var operationQueue = OperationQueue.current
    
    //MARK: - Lifecycle
    
    func start() {
        
        guard motionManager.isDeviceMotionAvailable == true else {
            return
        }
        
        guard let queue = operationQueue else {
            return
        }
        
        motionManager.startDeviceMotionUpdates(to: queue) { motion, error in
            
            guard error == nil else {
                self.orientationIsValid = false
                return
            }
            
            guard let motionData = motion else {
                self.orientationIsValid = false
                return
            }
            
            // Orientation
            let deviationFromVertical =  Double.pi/2 - fabs(motionData.attitude.pitch)

            if deviationFromVertical > MotionController.orientationDeviationMaxForValid {
                self.orientationIsValid = false
            } else {
                self.orientationIsValid = true
            }
            
            // angular velocity
            let angularVelocity = fabs(sqrt(pow(motionData.rotationRate.x, 2) + pow(motionData.rotationRate.x, 2) + pow(motionData.rotationRate.x, 2)))
            
            if angularVelocity > MotionController.angularVelocityMaxForValid {
                self.angularVeclocityIsValid = false
            } else {
                self.angularVeclocityIsValid = true
            }
            
            // acceleration
            let acceleration = fabs(sqrt(pow(motionData.userAcceleration.x, 2) + pow(motionData.userAcceleration.y, 2) + pow(motionData.userAcceleration.z, 2)))
            
            if acceleration > MotionController.accelerationMaxForValid {
                self.accelerationIsValid = false
            } else {
                self.accelerationIsValid = true
            }
            
            self.update()
        }
    }
    
    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    deinit {
        stop()
    }
    
    //MARK: - Validity Update
    
    func update() {
        isDynamicValid = accelerationIsValid && orientationIsValid && angularVeclocityIsValid
    }
}
