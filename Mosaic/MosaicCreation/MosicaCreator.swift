//
//  MosicaCreator.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit

enum MosaicCreationError {
    case MosaicCreationInProgress
    case QualityOutOfBounds
    case GridSizeOutOfBounds
}

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
}
