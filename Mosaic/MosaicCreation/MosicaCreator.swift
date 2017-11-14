//
//  MosicaCreator.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit
import Photos

enum MosaicCreationState {
    case NotStarted
    case PreprocessingInProgress
    case PreprocessingComplete
    case InProgress
    case Complete
}

// 1无效状态 2图片质量大小超出范围 3图片网格大小超出范围
enum MosaicCreationError: Error {
    case InvalidState
    case QualityOutOfBounds
    case GridSizeOutOfBounds
}

struct MosaicCreationConstants {
    static let gridSizeMin = TenPointAverageConstants.gridsAcross
    static let gridSizeMax = 75
    
    static let qualityMin = 1
    static let qualityMax = 100
}

class MosaicCreator {
    
    var imageSelector : ImageSelection
    var reference : UIImage
    private var state : MosaicCreationState
    private var _gridSizePoints : Int
    private var _quality : Int = (MosaicCreationConstants.qualityMax + MosaicCreationConstants.qualityMin)/2
    private var compositeContext: CGContext
    var timer : MosaicCreationTimer
    
    private var totalGridSpaces : Int
    private var gridSpacesFilled : Int
    
    var drawingThreads : Int
    
    var compositeImage : UIImage {
        get {
            let cgImage = self.compositeContext.makeImage()!
            return UIImage.init(cgImage: cgImage)
        }
    }
    
    func updateReference(new: UIImage) {
        
        self.reference = new
        
        self.totalGridSpaces = 0
        self.gridSpacesFilled = 0
        
        self.imageSelector.updateRef(new: new)
        
        
        UIGraphicsBeginImageContextWithOptions(self.reference.size, false, 0)
        self.compositeContext = UIGraphicsGetCurrentContext()!
        UIGraphicsPopContext()
        
        
        do {
            self._gridSizePoints = 0
            try self.setGridSizePoints((MosaicCreationConstants.gridSizeMax + MosaicCreationConstants.gridSizeMin)/2)
        } catch {
            print("error initializing grid size")
        }
        
    }
    
    // 4.对选择好的图片初始化： 未开始状态 马赛克创建时间---------------------------------------------
    init(reference: UIImage) {
        self.state = .NotStarted
        self.reference = reference
        self.timer = MosaicCreationTimer(enabled: false)
        self.imageSelector = MetalImageSelection(refImage: reference, timer: self.timer)
        
        self.totalGridSpaces = 0
        self.gridSpacesFilled = 0
        self.drawingThreads = 1
        
        // 设置要创建图像的尺寸为所选择的图像尺寸
        UIGraphicsBeginImageContextWithOptions(self.reference.size, false, 0)
        // 返回当前图形上下文
        self.compositeContext = UIGraphicsGetCurrentContext()!
        // 从栈中删除顶部当前图形上下文，恢复先前的上下文。
        UIGraphicsPopContext()
        
        
        do {
            self._gridSizePoints = 0
            try self.setGridSizePoints((MosaicCreationConstants.gridSizeMax + MosaicCreationConstants.gridSizeMin)/2)
        } catch {
            print("error initializing grid size")
        }
    }
    
    func getGridSizePoints() -> Int {
        return self._gridSizePoints
    }
    //  设置网格
    func setGridSizePoints(_ gridSizePoints : Int) throws {
        guard (gridSizePoints >= MosaicCreationConstants.gridSizeMin &&
            gridSizePoints <= MosaicCreationConstants.gridSizeMax) else {
                throw MosaicCreationError.GridSizeOutOfBounds
        }
        let spacesInRow = (MosaicCreationConstants.gridSizeMax - gridSizePoints) + 10
        self._gridSizePoints = max(Int(min(self.reference.size.width, self.reference.size.height)) / spacesInRow, MosaicCreationConstants.gridSizeMin)
    }
    
    func getQuality() -> Int {
        return self._quality
    }
    // 设置质量
    func setQuality(_ quality: Int) throws {
        guard (quality >= MosaicCreationConstants.qualityMin &&
            quality <= MosaicCreationConstants.qualityMax) else {
                throw MosaicCreationError.QualityOutOfBounds
        }
        self._quality = quality
    }
    

    func preprocess(complete: @escaping () -> Void) throws -> Void {
        if (self.state == .InProgress || self.state == .PreprocessingInProgress) {
            throw MosaicCreationError.InvalidState
        } else if (self.state == .PreprocessingComplete || self.state == .Complete) {
            self.state = .PreprocessingComplete
            complete()
        } else {
            //Needs to preprocess
            self.state = .PreprocessingInProgress
            try self.imageSelector.preprocess(then: {() -> Void in
                self.state = .PreprocessingComplete
                print("done preprocessing. array:")
                complete()
            })
        }
    }
    
    func begin(tick : @escaping () -> Void, complete : @escaping () -> Void) throws -> Void {
        
        //        guard (self.state == .PreprocessingComplete || self.state == .Complete) else {
        //            throw MosaicCreationError.InvalidState
        //        }
        
        // step 记录任务的开始 停止 持续时间
        let step = self.timer.task("Photo Mosaic Generation")
        self.state = .InProgress
        let numRows = Int(self.reference.size.height) / self._gridSizePoints
        let numCols = Int(self.reference.size.width) / self._gridSizePoints
        self.totalGridSpaces = numRows * numCols
        self.gridSpacesFilled = 0
        try self.imageSelector.select(gridSizePoints: self._gridSizePoints, numGridSpaces: self.totalGridSpaces, numRows: numRows, numCols: numCols, quality: self._quality, onSelect:
        {(assetIds) -> Void in
            step("Selecting nearest matches")
            var assetData : [String : PHAsset] = [:]
            let choiceAssets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
            choiceAssets.enumerateObjects({ (asset: PHAsset, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
                assetData[asset.localIdentifier] = asset
            })
            
            let imageManager = PHImageManager()
            step("Retrieving Local Identifiers")
            
            var squaresComplete = 0
            for threadIndex in 0 ..< self.drawingThreads {
                DispatchQueue.global(qos: .userInitiated).async {
                    for squareId in stride(from: threadIndex, to: numRows * numCols, by: self.drawingThreads) {
                        let col = squareId % numCols
                        let row = squareId / numCols
                        let x = col * self._gridSizePoints
                        let y = row * self._gridSizePoints
                        
                        //Make sure that we cover the whole image and don't go over!
                        let rectWidth = min(Int(self.reference.size.width) - x, self._gridSizePoints)
                        let rectHeight = min(Int(self.reference.size.height) - y, self._gridSizePoints)
                        
                        let targetSize = CGSize(width: rectWidth, height: rectHeight)
                        let options = PHImageRequestOptions()
                        imageManager.requestImage(for: assetData[assetIds[row*numCols + col]]!, targetSize: targetSize, contentMode: PHImageContentMode.default, options: options, resultHandler: {(result, info) -> Void in
                            DispatchQueue.main.async {
                                UIGraphicsPushContext(self.compositeContext)
                                
                                let drawRect = CGRect(x: x, y: y, width: Int(rectWidth), height: Int(rectHeight))
                                
                                result!.draw(in: drawRect)
                                UIGraphicsPopContext()
                                tick()
                                squaresComplete += 1
                                print(squaresComplete)
                                if (squaresComplete == numRows * numCols) {
                                    step("Drawing onto Canvas")
                                    self.state = .Complete
                                    self.timer.complete(report: true)
                                    complete()
                                }
                            }
                        })
                    }
                }
            }
        })
    }
    
    func progress() -> Int {
        if (!(self.state == .InProgress)) {return 0}
        return Int(100.0 * (Float(self.gridSpacesFilled) / Float(self.totalGridSpaces)))
    }
}

