//
//  PreProcessLibrary.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/15.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import Photos

func preprocessLibrary(complete: @escaping () -> Void) -> Void {
    // 全局队列异步并行 后台优先级
    DispatchQueue.global(qos: .background).async {
        // 查看相册授权
        PHPhotoLibrary.requestAuthorization({ (status) in
            switch status {
            case .authorized:
                let userAlbumsOptions = PHFetchOptions() // 过滤和排序的途径
                userAlbumsOptions.predicate = NSPredicate(format: "estimatedAssetCount > 0") // 所有照片
                let userAlbums = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.album, subtype: PHAssetCollectionSubtype.albumSyncedAlbum, options: userAlbumsOptions)
                print("获得相片")
                // 预处理: 存储相册库所有照片的KPA值-------------------------------
                
                
            case .denied, .restricted:
                print("Library Access Denied!")
            case .notDetermined:
                print("Library Access Not Determined!")
            }
        })
    }
}

func preProcessallPhoto(<#parameters#>) -> <#return type#> {
    <#function body#>
}
