//
//  TPAStorage.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/13.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import Photos


protocol TPAStorage : NSCoding {
    
    var pListPath : String {get set}
    
    init()
    func insert(asset : String, tpa: TenPointAverage) -> Void
    func findNearestMatch(to refTPA: TenPointAverage) -> (closest: String, diff: Float)?
    func isMember(_ asset: String) -> Bool
    
}
