//
//  MosicaCreator.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit

// 马赛克创造错误 预处理 质量、网格超出界限
enum MosaicCreationError: Error {
    case MosaicCreationInProgress
    case QualityOutOfBounds
    case GridSizeOutOfBounds
}

// 质量、网格边界值
struct MosaicCreationConstants {
    static let gridSizeMin = 10
    static let gridSizeMax = 100
    
    static let qualityMin = 0
    static let qualityMax = 100
}

class MosaicCreator {
    private var imageSelector:  ImageSelection
    private var reference:      UIImage
    private var inProgress:     Bool
    private var gridSizePotints: Int = (MosaicCreationConstants.gridSizeMax + MosaicCreationConstants.gridSizeMin)/2
    private var quality: Int = (MosaicCreationConstants.qualityMax + MosaicCreationConstants.qualityMin)/2
    
    init(reference: UIImage) {
        self.inProgress = false
        self.reference = reference
        self.imageSelector = NaiveImageSelection(refImage: reference)
    }
    // 设置网格
    func setGridSize(gridSizePoints: Int) throws {
        guard (gridSizePoints >= MosaicCreationConstants.gridSizeMin && gridSizePoints <= MosaicCreationConstants.gridSizeMax) else {
            throw MosaicCreationError.GridSizeOutOfBounds
        }
        self.gridSizePotints = gridSizePoints
    }
    // 设置质量
    func setQuality(quality: Int) throws {
        guard (quality >= MosaicCreationConstants.qualityMin && quality <= MosaicCreationConstants.qualityMax) else {
            throw MosaicCreationError.QualityOutOfBounds
        }
        self.quality = quality
    }
    
    func begin() throws -> Void {
        if (self.inProgress) {
            throw MosaicCreationError.MosaicCreationInProgress
        } else {
            self.inProgress = true
            try self.imageSelector.select(gridSizePoints: gridSizePotints, onSelect: { (choice: ImageChoice) in
                return
            })
        }
    }
}
