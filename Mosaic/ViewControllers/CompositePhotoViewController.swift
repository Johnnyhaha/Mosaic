//
//  CompositePhotoViewController.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import UIKit

class CompositePhotoViewController: UIViewController {

    @IBOutlet weak var compositePhoto: UIImageView!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
//    var mosaicCreator: MosaicCreator!
    var compositePhotoImage: UIImage = UIImage()
    var canSavePhoto = false
    var results: [UIImage] = []
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("beginning mosaic")
        self.compositePhoto.contentMode = UIViewContentMode.scaleAspectFit
//        self.compositePhotoImage = self.mosaicCreator.compositeImage
//        self.compositePhoto.image = self.compositePhotoImage
        
//        do {
//            var lastRefresh : CFAbsoluteTime = 0
//            // 1.???--------------------------
//            if (false) {
//                let benchmarker = MosaicBenchmarker(creator: self.mosaicCreator)
//                var drawingThreads : Int = 1
//                benchmarker.addVariable(name: "Drawing Threads", next: {() -> Any? in
//                    if (drawingThreads > 16) {
//                        return nil
//                    }
//                    self.mosaicCreator.drawingThreads = drawingThreads
//                    drawingThreads *= 2
//                    return drawingThreads / 2
//                })
//                try benchmarker.begin(tick: {() -> Void in
//                    return
//                }, complete: {() -> Void in
//                    return
//                })
//            } else {
//                    // 3.
//                    try self.mosaicCreator.begin(tick: {() -> Void in
//                        print("tick!")
//                        let newTime = CFAbsoluteTimeGetCurrent()
//                        if (newTime - lastRefresh > 0.25) {
//                            self.compositePhotoImage = self.mosaicCreator.compositeImage
//                            self.compositePhoto.image = self.compositePhotoImage
//                            lastRefresh = newTime
//                        }
//                    }, complete: {() -> Void in
//                        // This will be called when the mosaic is complete.
//                        print("Mosaic complete!")
//
//                        self.compositePhotoImage = self.mosaicCreator.compositeImage
//                        self.compositePhoto.image = self.compositePhotoImage
//                        self.canSavePhoto = true
//
//                    })
//                }
//            }
//        catch {
//            print("oh no")
//        }
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
