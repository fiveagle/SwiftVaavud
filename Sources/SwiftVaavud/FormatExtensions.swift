//
//  FormatExtensions.swift
//  
//
//  Created by Marco Di Peco on 03/03/2020.
//

import Foundation

public extension Double {
    
    func windSpeed(in unit: UnitSpeed) -> String {
        let speed = Measurement<UnitSpeed>(value: self,
                                           unit: .metersPerSecond)

        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumSignificantDigits = 3
        return formatter.string(from: speed.converted(to: unit))
    }
    
    func pressure(in unit: UnitPressure) -> String {
        
        let pressure = Measurement<UnitPressure>(value: self,
                                                 unit: .kilopascals)

        let formatter = MeasurementFormatter()
        return formatter.string(from: pressure.converted(to: unit))
    }
}
