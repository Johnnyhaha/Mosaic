//
//  MetalImageSelection.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import UIKit
import Photos

struct MetalSelectionConstants {
    //    static let skipSize = 5 // 检查时跳过的像素值
}

enum MetalSelectionError: Error {
    case InvalidSkipSize // 像素值无效
    case RegionMismatch // 图片大小不匹配
}

class MetalImageSelection: ImageSelection {
    private var referenceImage: UIImage
    private var allPhotos:      PHFetchResult<PHAsset>? //定义获得图片
    private var imageManager:   PHImageManager //定义加载图片
    private var skipSize:       Int
    private var tpa:            TenPointAveraging
    
    required init(refImage: UIImage) {
        self.referenceImage = refImage
        self.imageManager = PHImageManager()
        self.allPhotos = nil
        self.skipSize = 0
        self.tpa = TenPointAveraging()
    }
    
    //    选择图片的像素区域与其他图片相差RGB数值比较。寻找相差数值最小，颜色最接近的图片
    private func compareRegions(refRegion: CGRect, otherImage: UIImage, otherRegion: CGRect) throws -> CGFloat {
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
//        for deltaY in stride(from: 0, to: refRegion.height - 1, by: 1 + self.skipSize) {
//            //            print("row \(deltaY+1)/\(refRegion.height) (current fit: \(fit))")
//            for deltaX in stride(from: 0, to: refRegion.width - 1, by: 1 + self.skipSize) {
//                //                图片中像素点的位置和颜色
//                let refPoint = CGPoint(x: Int(refRegion.topLeft.x) + deltaX, y: Int(refRegion.topLeft.y) + deltaY)
//                //                let refColor = self.referenceImage.getPixelColor(pos: refPoint)
//                
//                let otherPoint = CGPoint(x: Int(otherRegion.topLeft.x) + deltaX, y: Int(otherRegion.topLeft.y) + deltaY)
//                                fit += self.comparePoints(refPoint: refPoint, otherImage: otherImage, otherPoint: otherPoint)
//                //                let otherColor = otherImage.getPixelColor(pos: otherPoint)
//                //
//                //                refColor.getRed(&refRGB.red, green: &refRGB.green, blue: &refRGB.blue, alpha: nil)
//                //                otherColor.getRed(&othRGB.red, green: &othRGB.green, blue: &othRGB.blue, alpha: nil)
//                //                let redAbs = abs(refRGB.red - othRGB.red)
//                //                let blueAbs = abs(refRGB.blue - othRGB.blue)
//                //                let greenAbs = abs(refRGB.green - othRGB.green)
//                //                fit += redAbs + blueAbs + greenAbs
//                
//                //                fit += abs(refRGB.red - othRGB.red) + abs(refRGB.blue - othRGB.blue) + abs(refRGB.green - othRGB.green)
//            }
//        }
        return fit
    }
    
    private func findBestMatch(row: Int, col: Int, refRegion: CGRect, onSelect: @escaping(ImageChoice) -> Void) {
        //        图片中的什么位置和区域正在寻找最匹配的图片
        print("(\(row), \(col)) finding best match.")
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
                            let choiceRegion = CGRect(x: 0, y: 0, width: Int(refRegion.width), height: Int(refRegion.height))
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
    
    
    func select(gridSizePoints: Int, quality: Int, onSelect: @escaping (ImageChoice) -> Void) throws -> Void {
        // 预处理相册库
        print("Pre-processing library...")
        try self.tpa.begin(complete: {() -> Void in
            
            print("Done pre-processing.")
            print("Finding best matches...")
            
            let numRows: Int = Int(self.referenceImage.size.height) / gridSizePoints
            let numCols: Int = Int(self.referenceImage.size.width) / gridSizePoints
            
            for row in 0 ... numRows-1 {
                for col in 0 ... numCols-1 {
                    self.findBestMatch(row: row, col: col, refRegion: CGRect(x: col * gridSizePoints, y: row * gridSizePoints, width: gridSizePoints, height: gridSizePoints), onSelect: onSelect)
                }
            }
        })
    }
}
