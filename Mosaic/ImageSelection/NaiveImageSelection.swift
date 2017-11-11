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

struct NaiveSelectionConstants {
//    static let skipSize = 5 // 检查时跳过的像素值
}

enum NaiveSelectionError: Error {
    case InvalidSkipSize // 像素值无效
    case RegionMismatch // 图片大小不匹配
}

//// 图片颜色的RGB值和透明度
//extension UIImage {
//    func getPixelColor(pos: CGPoint) -> UIColor {
//        let pixelData = self.cgImage!.dataProvider!.data
//        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
//        // 图片像素信息
//        let pixelInfo: Int = ((Int(self.size.width) * Int(pos.y)) + Int(pos.x)) * 4
//
//        let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
//        let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
//        let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
//        let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
//
//        return UIColor(red: r, green: g, blue: b, alpha: a)
//    }
//}

class NaiveImageSelection: ImageSelection {
    private var referenceImage: UIImage
    private var referencePixelData: CFData
    private var allPhotos:      PHFetchResult<PHAsset>? //定义获得图片
    private var imageManager:   PHImageManager //定义加载图片
    private var skipSize:       Int
    
    required init(refImage: UIImage) {
        self.referenceImage = refImage
        self.referencePixelData = self.referenceImage.cgImage!.dataProvider!.data!
        self.imageManager = PHImageManager()
        self.allPhotos = nil
        self.skipSize = 0
        
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
    
    private func comparePoints(refPoint: CGPoint, otherImage: UIImage, otherPoint: CGPoint) -> CGFloat {
        let otherPixelData = otherImage.cgImage!.dataProvider!.data
        let refData: UnsafePointer<UInt8> = CFDataGetBytePtr(self.referencePixelData)
        let othData: UnsafePointer<UInt8> = CFDataGetBytePtr(otherPixelData)
        
        let refPixelIndex: Int = ((Int(referenceImage.size.width) * Int(refPoint.y)) + Int(refPoint.x)) * 4
        let otherPixelIndex: Int = ((Int(otherImage.size.width) * Int(otherPoint.y)) + Int(otherPoint.x)) * 4
        
        let redDiff = Int(refData[refPixelIndex]) - Int(othData[otherPixelIndex])
        let greenDiff = Int(refData[refPixelIndex+1]) - Int(othData[otherPixelIndex+1])
        let blueDiff = Int(refData[refPixelIndex+2]) - Int(othData[otherPixelIndex+2])
        return CGFloat(abs(redDiff) + abs(greenDiff) + abs(blueDiff)) / CGFloat(255.0)
    }
    
//    选择图片的像素区域与其他图片相差RGB数值比较。寻找相差数值最小，颜色最接近的图片
    private func compareRegions(refRegion: Region, otherImage: UIImage, otherRegion: Region) throws -> CGFloat {
        guard (refRegion.width == otherRegion.width && refRegion.height == otherRegion.height) else {
            throw NaiveSelectionError.RegionMismatch
        }
        guard (self.skipSize >= 0) else {
            throw NaiveSelectionError.InvalidSkipSize
        }
        
        var fit: CGFloat = 0.0
//        var refRGB: (red: CGFloat, blue: CGFloat, green: CGFloat) = (0,0,0)
//        var othRGB: (red: CGFloat, blue: CGFloat, green: CGFloat) = (0,0,0)
        
//        遍历图片中每隔26个单位的一个像素点RGB的数值
        for deltaY in stride(from: 0, to: refRegion.height - 1, by: 1 + self.skipSize) {
//            print("row \(deltaY+1)/\(refRegion.height) (current fit: \(fit))")
            for deltaX in stride(from: 0, to: refRegion.width - 1, by: 1 + self.skipSize) {
//                图片中像素点的位置和颜色
                let refPoint = CGPoint(x: Int(refRegion.topLeft.x) + deltaX, y: Int(refRegion.topLeft.y) + deltaY)
//                let refColor = self.referenceImage.getPixelColor(pos: refPoint)
                
                let otherPoint = CGPoint(x: Int(otherRegion.topLeft.x) + deltaX, y: Int(otherRegion.topLeft.y) + deltaY)
                fit += self.comparePoints(refPoint: refPoint, otherImage: otherImage, otherPoint: otherPoint)
//                let otherColor = otherImage.getPixelColor(pos: otherPoint)
//
//                refColor.getRed(&refRGB.red, green: &refRGB.green, blue: &refRGB.blue, alpha: nil)
//                otherColor.getRed(&othRGB.red, green: &othRGB.green, blue: &othRGB.blue, alpha: nil)
//                let redAbs = abs(refRGB.red - othRGB.red)
//                let blueAbs = abs(refRGB.blue - othRGB.blue)
//                let greenAbs = abs(refRGB.green - othRGB.green)
//                fit += redAbs + blueAbs + greenAbs
                
//                fit += abs(refRGB.red - othRGB.red) + abs(refRGB.blue - othRGB.blue) + abs(refRGB.green - othRGB.green)
            }
        }
        return fit
    }
    
    func select(gridSizePoints: Int, quality: Int, onSelect: @escaping (ImageChoice) -> Void) throws -> Void {
        if (allPhotos == nil) {
            // 没有检索到图片，预处理没有完成
            throw ImageSelectionError.PreprocessingIncomplete
        }
        self.skipSize = MosaicCreationConstants.qualityMax - quality - MosaicCreationConstants.qualityMin
        // 把图片分成网格
        let numRows: Int = Int(self.referenceImage.size.height) / gridSizePoints
        let numCols: Int = Int(self.referenceImage.size.width) / gridSizePoints
//        print("selecting with grid size \(gridSizePoints), \(numRows) rows, and \(numCols) columns.")
        for row in 0 ... numRows-1 {
            for col in 0 ... numCols-1 {
                let topLeft: CGPoint = CGPoint(x: col * gridSizePoints, y: row * gridSizePoints)
                let bottomRight: CGPoint = CGPoint(x: (col + 1) * gridSizePoints, y: (row + 1) * gridSizePoints)
                // 输入网格在图像中的位置和范围信息 去找到最匹配的图片
                findBestMatch(row: row, col: col, refRegion: Region(topLeft: topLeft, bottomRight: bottomRight), onSelect: onSelect)
            }
        }
    }
    
    private func findBestMatch(row: Int, col: Int, refRegion: Region, onSelect: @escaping(ImageChoice) -> Void) {
//        图片中的什么位置和区域正在寻找最匹配的图片
        print("(\(row), \(col)) finding best match (coordinates \(refRegion.topLeft) <-> \(refRegion.bottomRight)")
        var bestMatch: ImageChoice? = nil
        
        // 处理资源
        allPhotos?.enumerateObjects({ (asset: PHAsset, index: Int, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            if (asset.mediaType == .image) {
                let targetSize = CGSize(width: refRegion.width, height: refRegion.height)
                let options = PHImageRequestOptions()
                options.isSynchronous = true
                
                self.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: PHImageContentMode.default, options: options, resultHandler: { (result, info) -> Void in
                    if (result != nil) {
                        
                        do {
                            let choiceRegion = Region(topLeft: CGPoint.zero, bottomRight: CGPoint(x: refRegion.width, y: refRegion.height))
                            let fit: CGFloat = try self.compareRegions(refRegion: refRegion, otherImage: result!, otherRegion: choiceRegion)
                            
                            if (bestMatch == nil || fit < bestMatch!.fit) {
                                bestMatch = ImageChoice(position: (row,col), image: result!, region: choiceRegion, fit: fit)
                            }
                        } catch {
                            print("Region mismatch!!!")
                        }
//                        // 找到选择的图片
//                        let choice = ImageChoice(position: (row, col), image: result!, topLeft: topLeft, bottomRight: bottomRight)
//                        stop.pointee = true
//                        onSelect(choice)
                    }
                })
            }
        })
        onSelect(bestMatch!)
    }
}
