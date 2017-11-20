//
//  MosaicCreator.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/15.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit
import Photos

struct MosaicCreationConstants {
    static let gridSizeMin = KPointAverageConstants.gridsAcross
    static let gridSizeMax = 75
    
    static let qualityMin = 1
    static let qualityMax = 100
}

class MosaicCreator {
    var imageSelector: MetalImageSelection
    var reference: UIImage
    private var compositeContext: CGContext
    private var _gridSizePoints : Int
    private var _quality : Int = (MosaicCreationConstants.qualityMax + MosaicCreationConstants.qualityMin)/2
    
    private var totalGridSpaces : Int // 所有网格块的数量
    private var gridSpacesFilled : Int // 填入照片的网格块数量
    var drawingThreads : Int // 渲染进程
    
    var compositeImage : UIImage {
        get {
            let cgImage = self.compositeContext.makeImage()!
            return UIImage.init(cgImage: cgImage)
        }
    }
    
    
    // 4.对选择好的图片初始化
    init(reference: UIImage) {
        self.reference = reference.scaleImage(scaleSize: 2.0)
        self.totalGridSpaces = 0
        self.gridSpacesFilled = 0
        self.drawingThreads = 1
        self.imageSelector = MetalImageSelection(refImage: reference)
        print(self.reference.size.width)
        // 设置要创建图像的尺寸为所选择的图像尺寸
        UIGraphicsBeginImageContextWithOptions(self.reference.size, false, 0)
        // 返回当前图形上下文
        self.compositeContext = UIGraphicsGetCurrentContext()!
        // 从栈中删除顶部当前图形上下文，恢复先前的上下文。
        UIGraphicsPopContext()
        
        
        self._gridSizePoints = 0
        self.setGridSizePoints((MosaicCreationConstants.gridSizeMax + MosaicCreationConstants.gridSizeMin)/2)
       
    }
    
    //  设置网格
    func setGridSizePoints(_ gridSizePoints : Int) {
        guard (gridSizePoints >= MosaicCreationConstants.gridSizeMin &&
            gridSizePoints <= MosaicCreationConstants.gridSizeMax) else {
            return print("网格大小超出范围")
        }
        // 每格高度 最小为10
        let spacesInRow = (MosaicCreationConstants.gridSizeMax - gridSizePoints) + 10
        self._gridSizePoints = max(Int(min(self.reference.size.width, self.reference.size.height)) / spacesInRow, MosaicCreationConstants.gridSizeMin)
    }
    
    
    // 设置质量
    func setQuality(_ quality: Int) {
        guard (quality >= MosaicCreationConstants.qualityMin &&
            quality <= MosaicCreationConstants.qualityMax) else {
            return print("质量大小超出范围")
        }
        self._quality = quality
    }
    
    func preprocess(complete: @escaping () -> Void) throws -> Void {
        
        
            
            try self.imageSelector.preprocess(then: {() -> Void in
                
                print("done preprocessing. array:")
                complete()
            })
    }
    

    func begin(complete: @escaping() -> Void) throws -> Void {
        // 合成图像行列数
        let numRows = Int(self.reference.size.height) / self._gridSizePoints
        let numCols = Int(self.reference.size.width) / self._gridSizePoints
        self.totalGridSpaces = numRows * numCols
        self.gridSpacesFilled = 0
        try self.imageSelector.select(gridSizePoints: self._gridSizePoints, numGridSpaces: self.totalGridSpaces, numRows: numRows, numCols: numCols, quality: self._quality, completeSelect: { (assetIds) in
            print("获得最匹配照片的索引 开始选择最接近的匹配图片")
            var assetData : [String : PHAsset] = [:]
            let choiceAssets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
            choiceAssets.enumerateObjects({ (asset: PHAsset, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
                assetData[asset.localIdentifier] = asset
            })
            
            let imageManager = PHImageManager()
            print("根据索引取照片，开始着色")
            
            var squaresComplete = 0
            for threadIndex in 0 ..< self.drawingThreads {
                // 最高优先级
                DispatchQueue.global(qos: .userInitiated).async {
                    for squareId in stride(from: threadIndex, to: numRows * numCols, by: self.drawingThreads) {
                        let col = squareId % numCols
                        let row = squareId / numCols
                        let x = col * self._gridSizePoints
                        let y = row * self._gridSizePoints
                        
                        // 确保覆盖整个图片且不超出范围 实际格子高度和宽度
                        let rectWidth = min(Int(self.reference.size.width) - x, self._gridSizePoints)
                        let rectHeight = min(Int(self.reference.size.height) - y, self._gridSizePoints)
                        
                        let targetSize = CGSize(width: rectWidth, height: rectHeight)
                        let options = PHImageRequestOptions()
                        
                        // ?-------------------------------------
                        
                        imageManager.requestImage(for: assetData[assetIds[row*numCols + col]]!, targetSize: targetSize, contentMode: PHImageContentMode.default, options: options, resultHandler: {(result, info) -> Void in
                            DispatchQueue.main.async {
                                // 更改当前上下文 压栈当前的绘制对象，生成新的绘制图层
                                UIGraphicsPushContext(self.compositeContext)
                                
                                let drawRect = CGRect(x: x, y: y, width: Int(rectWidth), height: Int(rectHeight))
                                
                                result!.draw(in: drawRect)
                                UIGraphicsPopContext()
                                squaresComplete += 1
                                if (squaresComplete == numCols * numRows) {
                                    print("完成着色")                                    
                                    complete()
                                }
                            }
                        })
                        
                    }
                }
            }
        })
        
        
        
    }
    
}
