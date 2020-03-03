//
//  Array+Grouping.swift
//  VaavudSDK
//
//  Created by Marco Di Peco on 03/11/2019.
//  Copyright © 2019 Marco Di Peco. All rights reserved.
//

import Foundation

extension Array {
    public func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
