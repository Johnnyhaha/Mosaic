//
//  NaiveImageSelection.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit
import Photos

class NaiveImageSelection: ImageSelection {
    private var referenceImage: UIImage
    private var allPhotos:      PHFetchResult<PHAsset>? //定义获得图片
    private var imageManager:   PHImageManager //定义加载图片
    
    required init(refImage: UIImage) {
        self.referenceImage = refImage
        self.imageManager = PHImageManager()
        self.allPhotos = nil
        
        // 相册四种授权状态
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                let fetchOptions = PHFetchOptions() // 获得相片
                self.allPhotos = PHAsset.fetchAssets(with: fetchOptions) // 检索相片
            case .denied, .restricted:
                print("Library Access Denied!")
            case .notDetermined:
                print("Library Access Not Determined!")
            }
        }
    }
    
    func select(gridSizePoints: Int, onSelect: @escaping (ImageChoice) -> Void) throws -> Void {
        if (allPhotos == nil) {
            // 没有检索到图片，预处理没有完成
            throw ImageSelectionError.PreprocessingIncomplete
        }
        let numRows: Int = Int(self.referenceImage.size.height) / gridSizePoints
        let numCols: Int = Int(self.referenceImage.size.width) / gridSizePoints
        for row in 0 ... numRows-1 {
            for col in 0 ... numCols-1 {
                let topLeft: (Int, Int) = (col * gridSizePoints, row * gridSizePoints)
                let bottomRight: (Int, Int) = ((col + 1) * gridSizePoints, (row + 1) * gridSizePoints)
                // 找到选择的图像的位置信息
                findBestMatch(row: row, col: col, topLeft: topLeft, bottomRight: bottomRight, onSelect: onSelect)
            }
        }
    }
    
    private func findBestMatch(row: Int, col: Int, topLeft: (x: Int, y: Int), bottomRight: (x: Int, y: Int), onSelect: @escaping(ImageChoice) -> Void) {
        // 处理资源
        allPhotos?.enumerateObjects({ (asset: PHAsset, index: Int, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            if (asset.mediaType == .image) {
                self.imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: PHImageContentMode.default, options: PHImageRequestOptions(), resultHandler: { (result, info) -> Void in
                    if (result != nil) {
                        // 找到选择的图片
                        let choice = ImageChoice(position: (row, col), image: result!, topLeft: topLeft, bottomRight: bottomRight)
                        stop.pointee = true
                        onSelect(choice)
                    }
                })
            }
        })
    }
}
