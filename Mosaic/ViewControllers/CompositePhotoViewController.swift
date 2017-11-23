//
//  CompositePhotoViewController.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import UIKit

class CompositePhotoViewController: UIViewController {

    @IBOutlet weak var compositePhoto: UIImageView! = UIImageView()

    @IBOutlet weak var saveButton: UIButton!
    
    var mosaicCreator: MosaicCreator!
    var compositePhotoImage: UIImage = UIImage()
    var canSavePhoto = false
    var results: [UIImage] = []
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("开始合成马赛克")
        self.compositePhoto.contentMode = UIViewContentMode.scaleAspectFit
        self.compositePhoto.image = self.mosaicCreator.compositeImage
        
        do {
            try self.mosaicCreator.begin(complete: {() -> Void in
                print("马赛克完成!")
                self.compositePhoto.image = self.mosaicCreator.compositeImage
                self.canSavePhoto = true
            })
        } catch {
            print("合成错误")
        }
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func savePhoto(_ sender: Any) {
        saveButton.isSelected = !saveButton.isSelected
        if (self.canSavePhoto && saveButton.isSelected) {
            PhotoAlbumUtil.saveImageInAlbum(image: self.mosaicCreator.compositeImage, albumName: "马赛克") { (result) in
                switch result{
                case .success:
                    print("保存成功")
                case .denied:
                    print("被拒绝")
                case .error:
                    print("保存错误")
                }
            }
        }
        
    }
    

}
