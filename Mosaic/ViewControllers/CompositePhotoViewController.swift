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
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    var mosaicCreator: MosaicCreator!
    var compositePhotoImage: UIImage = UIImage()
    var canSavePhoto = false
    var results: [UIImage] = []
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("beginning mosaic")
        self.compositePhoto.image = self.mosaicCreator.compositeImage
        
        do {
            try self.mosaicCreator.begin(complete: {() -> Void in
                // This will be called when the mosaic is complete.
                print("Mosaic complete!")
                self.compositePhoto.image = self.mosaicCreator.compositeImage
            })
        } catch {
            print("oh shit")
        }
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func savePhoto(_ sender: Any) {
        
        if (self.canSavePhoto) {
            UIImageWriteToSavedPhotosAlbum(self.compositePhotoImage, nil, nil, nil)
        }
        
    }
    

}
