//
//  KPAArray.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/15.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation

class KPAArray: NSObject, KPAStorage, NSCoding {
    var pLiskpath : String = "array.plist"
    private var assets: Set<String>
    var kpaIds: [String]
    var kpaData : [UInt32]
    
    required override init() {
        self.assets = []
        self.kpaIds = []
        self.kpaData = []
    }
    
    // 存储5x5x3的kpa向量
    func insert(asset : String, kpa: KPointAverage) -> Void {
        self.assets.insert(asset)
        self.kpaIds.append(asset)
        for i in 0 ..< KPointAverageConstants.gridsAcross {
            for j in 0 ..< KPointAverageConstants.gridsAcross {
                for k in 0 ..< 3 {
                    self.kpaData.append(UInt32(kpa.gridAvg[i][j].get(k)))
                }
            }
        }
    }
    
    func findNearestMatch(to refkpa: KPointAverage) -> (closest: String, diff: Float)? {
        return nil
    }
    
    func isMember(_ asset: String) -> Bool {
        return self.assets.contains(asset)
    }
    
    //NSCoding
    
    required init?(coder aDecoder: NSCoder) {
        self.assets = aDecoder.decodeObject(forKey: "assets") as! Set<String>
        self.kpaIds = aDecoder.decodeObject(forKey: "kpaIds") as! [String]
        self.kpaData = aDecoder.decodeObject(forKey: "kpaData") as! [UInt32]
        print("Decoding averages")
        //        self.averages = aDecoder.decodeObject(forKey: "identifier_averages") as! [String : KPointAverage]
    }
    
    
    func encode(with aCoder: NSCoder) -> Void{
        //        print("Trying to encode averages")
        //        aCoder.encode(self.averages, forKey: "identifier_averages")
        aCoder.encode(self.assets, forKey: "assets")
        aCoder.encode(self.kpaIds, forKey: "kpaIds")
        aCoder.encode(self.kpaData, forKey: "kpaData")
        //        print("Averages encoded")
    }
    
}
