//
//  SavePhoto.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/21.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import Photos

//操作结果枚举
enum PhotoAlbumUtilResult {
    case success, error, denied
}

//相册操作工具类
class PhotoAlbumUtil: NSObject {
    
    //判断是否授权
    class func isAuthorized() -> Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized ||
            PHPhotoLibrary.authorizationStatus() == .notDetermined
    }
    
    //保存图片到相册
    class func saveImageInAlbum(image: UIImage, albumName: String = "", completion: ((_ result: PhotoAlbumUtilResult) -> ())?) {
        
        //权限验证
        if !isAuthorized() {
            completion?(.denied)
            return
        }
        var assetAlbum: PHAssetCollection?
        
        //如果指定的相册名称为空，则保存到相机胶卷。（否则保存到指定相册）
        if albumName.isEmpty {
            let list = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
            assetAlbum = list[0]
        } else {
            //看保存的指定相册是否存在
            let list = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            list.enumerateObjects({ (album, index, stop) in
                let assetCollection = album
                if albumName == assetCollection.localizedTitle {
                    assetAlbum = assetCollection
                    stop.initialize(to: true)
                }
            })
            //不存在的话则创建该相册
            if assetAlbum == nil {
                PHPhotoLibrary.shared().performChanges({ PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                }, completionHandler: { (isSuccess, error) in
                    self.saveImageInAlbum(image: image, albumName: albumName,
                                          completion: completion)
                })
                return
            }
        }
        
        //保存图片
        PHPhotoLibrary.shared().performChanges({
            //添加的相机胶卷
            let result = PHAssetChangeRequest.creationRequestForAsset(from: image)
            //是否要添加到相簿
            if !albumName.isEmpty {
                let assetPlaceholder = result.placeholderForCreatedAsset
                let albumChangeRequset = PHAssetCollectionChangeRequest(for: assetAlbum!)
                albumChangeRequset!.addAssets([assetPlaceholder!]  as NSArray)
            }
        }) { (isSuccess: Bool, error: Error?) in
            if isSuccess {
                completion?(.success)
            } else{
                print(error!.localizedDescription)
                completion?(.error)
            }
        }
    }
}
