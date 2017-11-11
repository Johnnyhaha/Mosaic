//
//  ImageSelection.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit

// 选择图像 位置 图片 
struct ImageChoice {
    var position    : (row: Int, col: Int)
    var image       : UIImage
    var region      : Region
    var fit         : CGFloat // 相片匹配程度有多好 0最好    
}

enum ImageSelectionError: Error {
    case PreprocessingIncomplete
    case LibraryAccessDenied
    case LibraryAccessNotDetermined
}

protocol ImageSelection {
    init(refImage : UIImage)
    func select(gridSizePoints : Int, quality: Int, onSelect : @escaping (ImageChoice) -> Void) throws -> Void
}
