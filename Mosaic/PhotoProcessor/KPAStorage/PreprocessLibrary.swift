//
//  PreprocessLibrary.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/15.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import Photos
import Metal
import MetalKit

class RGBFloat : NSObject, NSCoding {
    
    var r : CGFloat
    var g: CGFloat
    var b: CGFloat
    
    init(_ red : CGFloat, _ green : CGFloat, _ blue : CGFloat) {
        self.r = red
        self.g = green
        self.b = blue
    }
    
    func get(_ index: Int) -> CGFloat {
        if (index == 0) {
            return self.r
        } else if (index == 1) {
            return self.g
        } else {
            return self.b
        }
    }
    
    // RGB值相差
    static func -(left: RGBFloat, right: RGBFloat) -> CGFloat {
        return abs(left.r-right.r) + abs(left.g-right.g) + abs(left.b-right.b)
    }
    
    // RGB值相等
    static func ==(left: RGBFloat, right: RGBFloat) -> Bool {
        return left.r == right.r && left.g == right.g && left.b == right.b
    }
    
    override var description : String {
        return "(\(self.r), \(self.g), \(self.b))"
    }
    
    //编码解码
    
    func encode(with aCoder: NSCoder) -> Void {
        aCoder.encode(r, forKey: "r")
        aCoder.encode(g, forKey: "g")
        aCoder.encode(b, forKey: "b")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.r = aDecoder.decodeObject(forKey: "r") as! CGFloat
        self.g = aDecoder.decodeObject(forKey: "g") as! CGFloat
        self.b = aDecoder.decodeObject(forKey: "b") as! CGFloat
    }
    
}


class KPointAverage: NSObject, NSCoding {
    var totalAvg: RGBFloat = RGBFloat(0, 0, 0) // 整张图片RGB平均值
    var gridAvg: [[RGBFloat]] = Array(repeating: Array(repeating: RGBFloat(0,0,0), count: KPointAverageConstants.gridsAcross), count: KPointAverageConstants.gridsAcross)
    // 25个小格组成的RGB平均值向量
    override init () {
        super.init()
        //Setup if necessary
    }
    
    // 图片KPA值相差
    static func -(left: KPointAverage, right: KPointAverage) -> CGFloat {
        var diff : CGFloat = 0.0
        for row in 0 ..< KPointAverageConstants.gridsAcross {
            for col in 0 ..< KPointAverageConstants.gridsAcross {
                diff += pow(abs(left.gridAvg[row][col] - right.gridAvg[row][col]), 2) // pow 平方
            }
        }
        return sqrt(diff)
    }
    
    // 图片KPA值相等
    static func ==(left: KPointAverage, right: KPointAverage) -> Bool {
        for i in 0 ..< KPointAverageConstants.gridsAcross {
            for j in 0 ..< KPointAverageConstants.gridsAcross {
                if !(left.gridAvg[i][j] == right.gridAvg[i][j]) {
                    return false
                }
            }
        }
        return true
    }
    
    //For NSCoding
    
    func encode(with aCoder: NSCoder) -> Void {
        aCoder.encode(totalAvg, forKey: "totalAvg")
        aCoder.encode(gridAvg, forKey: "gridAvg")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.totalAvg = aDecoder.decodeObject(forKey: "totalAvg") as! RGBFloat
        self.gridAvg = aDecoder.decodeObject(forKey: "gridAvg") as! [[RGBFloat]]
    }
    
}

struct KPointAverageConstants {
    static let gridsAcross = 5
    static let numCells = KPointAverageConstants.gridsAcross * KPointAverageConstants.gridsAcross
}

class KPointAveraging {
    private var totalPhotos: Int
    private var photosComplete: Int
    static var storage: KPAArray = KPAArray()
    private static var imageManager : PHImageManager?
    static var metal: MetalPipeline? = nil
    var threadWidth : Int = 1
    
    init() {
        self.totalPhotos = 0
        self.photosComplete = 0
        if (KPointAveraging.imageManager == nil) {
            KPointAveraging.imageManager = PHImageManager()
        }
        if (KPointAveraging.metal == nil) {
            KPointAveraging.metal = MetalPipeline()
        }
    }
    
    
    // 预处理-------------------------------
    func preprocessLibrary(complete: @escaping () -> Void) -> Void {
        // 全局队列异步并行 后台优先级
        DispatchQueue.global(qos: .background).async {
            // 查看相册授权
            PHPhotoLibrary.requestAuthorization({ (status) in
                switch status {
                case .authorized:
//                    let userAlbumsOptions = PHFetchOptions() // 过滤和排序的途径
//                    userAlbumsOptions.predicate = NSPredicate(format: "estimatedAssetCount > 0") // 所有照片
                    let userAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
                    print("获得相片权限")
                    // 存储相册库所有照片的KPA值-------------------------------
                    print("开始预处理所有相片")
                    self.preprocessEachPhoto(userAlbums: userAlbums, complete: {(changed: Bool) -> Void in
                        // 相册库改变就重新存储
                        self.saveStorageToFile()
                        DispatchQueue.main.async {
                            complete()
                        }
                    })
                    
                case .denied, .restricted:
                    print("相册获取权限被拒")
                case .notDetermined:
                    print("相册获取权限未决定")
                }
            })
        }
    }
    
    private func preprocessEachPhoto(userAlbums: PHFetchResult<PHAssetCollection>, complete: @escaping (_ changed: Bool) -> Void) {
//        print("开始计算相册库照片KPA")
        var changed: Bool = false
        print(userAlbums.count)
//        userAlbums.enumerate
//        userAlbums.enumerateObjects ({ (collection, albumIndex, stop) in
        //遍历相册 PHAssetCollection: 一组代表性的相册 albumIndex: 相片的索引 序列号
        userAlbums.enumerateObjects({(collection: PHAssetCollection, albumIndex: Int, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
        
//            let options = PHFetchOptions()
            let fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            self.totalPhotos = fetchResult.count
            self.photosComplete = 0
            
            func step() {
                self.photosComplete += 1
//                print("完成照片\(self.photosComplete)/所有照片\(self.totalPhotos)")
                if (self.photosComplete == self.totalPhotos) {
                    print("完成所有照片，结束预处理")
                    complete(changed)
                    stop.pointee = true
                }
            }
            //遍历相册里的图片
            fetchResult.enumerateObjects({ (asset: PHAsset, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
                if (asset.mediaType == .image) {
                    let options = PHImageRequestOptions() // 请求图像
                    // 同步处理请求
                    options.isSynchronous = true
                    // 自动释放池
                    let _ = autoreleasepool {
                        KPointAveraging.imageManager?.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: PHImageContentMode.default, options: options, resultHandler: { (result, info) in
                            if (result != nil) {
                                self.calculateKPA(image: result!.cgImage!, synchronous: true, complete: { (kpa) in
                                    if (kpa != nil) {
                                        if (self.photosComplete % 40 == 0) {
                                            print("\(self.photosComplete)/\(self.totalPhotos)")
                                        }
                                        KPointAveraging.storage.insert(asset: asset.localIdentifier, kpa: kpa!)
                                    }
//                                    print("KPA 计算完毕")
                                    step() // 计算完KPA
                                })
                            } else {
                                step() // 没有照片 结束KPA计算
                            }
                        })
                    }
                    
                } else {
                    step() // 选择非照片格式 结束KPA计算
                }
                
            })
            
        })
        
    }
    
    //KPA 计算图片每一格的GRB平均值
    func calculateKPA(image: CGImage, synchronous: Bool, complete: @escaping (KPointAverage?) throws -> Void) -> Void {
        var texture: MTLTexture? = nil // 在GPU中存储图像数据
        do {
//            print("获得图片纹理")
            texture = try KPointAveraging.metal?.getImageTexture(image: image)
        } catch {
            print("无法获得图片纹理")
            do {
                try complete(nil)
            } catch {
                print("无法返回nil KPA. ")
            }
        }
        if (texture != nil) {
//            print("开始计算相册库照片KPA平均值")
            // 处理图像纹理
            KPointAveraging.metal?.processImageTexture(texture: texture!, width: image.width, height: image.height, threadWidth: self.threadWidth, complete: { (result: [UInt32]) -> Void in
                let kpa = KPointAverage() // 5x5x3维RGB值
                // 以5x5x3维RGB值的向量形式存储每一个图像的KPA值 numCells: 25
                for i in 0 ..< KPointAverageConstants.numCells {
                    let index = i * 3
                    let row = i / KPointAverageConstants.gridsAcross // gridsAcross: 5
                    let col = i % KPointAverageConstants.gridsAcross
                    // 图像的总平均RGB值
                    kpa.totalAvg.r += CGFloat(result[index])/CGFloat(KPointAverageConstants.numCells)
                    kpa.totalAvg.g += CGFloat(result[index+1])/CGFloat(KPointAverageConstants.numCells)
                    kpa.totalAvg.b += CGFloat(result[index+2])/CGFloat(KPointAverageConstants.numCells)
                    // 图像的每格的平均RGB值
                    kpa.gridAvg[row][col] = RGBFloat(CGFloat(Int(result[index])), CGFloat(Int(result[index+1])), CGFloat(Int(result[index+2])))
                }
                do {
                    try complete(kpa)
                } catch {
                    print("无法返回kpa")
                }
            })
        }
    }
    
    
    // Metal 查找与选择图片最匹配的图片
    func findNearestMatches(results: [UInt32], rows: Int, cols: Int, complete: @escaping ([String]) -> Void) -> Void {
        KPointAveraging.metal!.processNearestAverages(refKPAs: results, otherKPAs: KPointAveraging.storage.kpaData, rows: rows, cols: cols, threadWidth: 32, complete: {(matchIndexes) -> Void in
            // map 返回最匹配的图像的KPA索引
            complete(matchIndexes.map({(tpaIndex) -> String in
                return KPointAveraging.storage.kpaIds[Int(tpaIndex)]
            }))
        })
    }
    
    
    //File Management
    
    private func loadStorageFromFile() -> Void {
        
        print("Trying to load storage from file.\n")
        
        let fileURL = try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(String(KPointAverageConstants.gridsAcross) + KPointAveraging.storage.pListPath)
        
        if let stored = NSKeyedUnarchiver.unarchiveObject(withFile: fileURL.path) as? KPAArray {
            
            KPointAveraging.storage = stored
            print("self.storage successfully loaded from file.\n")
            
        }
    }
    
    private func saveStorageToFile() -> Void {
        
        print("Trying to save storage to file.\n")
        
        let toStore = NSKeyedArchiver.archivedData(withRootObject: KPointAveraging.storage)
        
        let fileURL = try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(String(KPointAverageConstants.gridsAcross) + KPointAveraging.storage.pListPath)
        
        do {
            try toStore.write(to: fileURL)
        } catch {
            print("Could not store self.storage to file.\n")
        }
        
    }

}

