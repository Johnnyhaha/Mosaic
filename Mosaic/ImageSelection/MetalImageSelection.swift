//
//  MetalImageSelection.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit

class MetalImageSelection: ImageSelection {
    private var referenceImage: UIImage
    
    required init(refImage: UIImage) {
        self.referenceImage = refImage
    }
    
    func select(gridSizePoints: Int, onSelect: @escaping (ImageChoice) -> Void) throws -> Void {
        return
    }
}
