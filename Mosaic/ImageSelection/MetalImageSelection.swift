//
//  MetalImageSelection.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/16.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import Photos
import UIKit

class MetalImageSelection {
    var referenceImage : UIImage
    var refCGImage : CGImage
    private var allPhotos : PHFetchResult<PHAsset>? //定义获得图片
    private var imageManager : PHImageManager //定义加载图片
    var kpa: KPointAveraging
    var numThreads : Int
    
        
    required init(refImage: UIImage) {
        self.referenceImage = refImage
        self.refCGImage = refImage.cgImageWithOrientation()
        self.imageManager = PHImageManager()
        self.allPhotos = nil
        self.kpa = KPointAveraging()
        self.numThreads = 4
    }
    
    
    func preprocess(then complete: @escaping () -> Void) throws -> Void {
        
        print("预处理相册")
        
        try self.kpa.preprocessLibrary(complete: {() -> Void in
            print("完成预处理")
            complete()
        })
    }
    
    
    func select(gridSizePoints: Int, numGridSpaces: Int, numRows: Int, numCols: Int, quality: Int, completeSelect: @escaping ([String]) -> Void) throws -> Void {
        let texture = try KPointAveraging.metal!.getImageTexture(image: self.refCGImage)
        KPointAveraging.metal?.processEntirePhotoTexture(texture: texture, gridSize: gridSizePoints, numGridSpaces: numGridSpaces, rows: numRows, cols: numCols, threadWidth: 32, complete: { (results) in
            print("正在查询KPA匹配")
            self.kpa.findNearestMatches(results: results, rows: numRows, cols: numCols, complete: completeSelect)
        })
    }
    
    
}
