//
//  MosicaCreator.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit

// 代表图片区域
class Region {
    var topLeft:        CGPoint
    var bottomRight:    CGPoint
    
    init(topLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft
        self.bottomRight = bottomRight
    }
    
    var height: Int {
        get {
            return Int(self.bottomRight.y - self.topLeft.y)
        }
    }
    
    var width: Int {
        get {
            return Int(self.bottomRight.x - self.topLeft.x)
        }
    }
}

// typealias 为已存在类型重新定义名字 一个是区域，一个是左上角和右下角点确定的区域
typealias region = (topLeft: CGPoint, bottomRight: CGPoint)

// 马赛克创造错误 预处理 质量、网格超出界限
enum MosaicCreationError: Error {
    case MosaicCreationInProgress
    case QualityOutOfBounds
    case GridSizeOutOfBounds
}

// 质量、网格边界值
struct MosaicCreationConstants {
    static let gridSizeMin = 10
    static let gridSizeMax = 500
    
    static let qualityMin = 0
    static let qualityMax = 100
}

class MosaicCreator {
    private var imageSelector:  ImageSelection
    private var reference:      UIImage
    private var inProgress:     Bool
    private var _gridSizePotints: Int = (MosaicCreationConstants.gridSizeMax + MosaicCreationConstants.gridSizeMin)/2
    private var _quality: Int = (MosaicCreationConstants.qualityMax + MosaicCreationConstants.qualityMin)/2
    
    init(reference: UIImage) {
        self.inProgress = false
        self.reference = reference
        self.imageSelector = NaiveImageSelection(refImage: reference)
    }
    
    func getGridSizePoints() -> Int {
        return self._gridSizePotints
    }
    // 设置网格
    func setGridSizePoints(gridSizePoints: Int) throws {
        guard (gridSizePoints >= MosaicCreationConstants.gridSizeMin && gridSizePoints <= MosaicCreationConstants.gridSizeMax) else {
            throw MosaicCreationError.GridSizeOutOfBounds
        }
        self._gridSizePotints = gridSizePoints
    }
    
    func getQuality() -> Int {
        return self._quality
    }
    // 设置质量
    func setQuality(quality: Int) throws {
        guard (quality >= MosaicCreationConstants.qualityMin && quality <= MosaicCreationConstants.qualityMax) else {
            throw MosaicCreationError.QualityOutOfBounds
        }
        self._quality = quality
    }
    
    func begin() throws -> Void {
        if (self.inProgress) {
            throw MosaicCreationError.MosaicCreationInProgress
        } else {
            self.inProgress = true
            try self.imageSelector.select(gridSizePoints: _gridSizePotints, onSelect: { (choice: ImageChoice) in
                return
            })
        }
    }
}
