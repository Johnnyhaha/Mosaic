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
    
    var mosaicCreator: MosaicCreator!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        DispatchQueue.global().async {
            do {
                try self.mosaicCreator.begin()
                self.compositePhoto.image = self.mosaicCreator.compositeImage
            }
            catch {
                print("Error with dispatching mosaicCreator.begin.")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    


}
