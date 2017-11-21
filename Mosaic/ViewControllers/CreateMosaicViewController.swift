//
//  CreateMosaicViewController.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import UIKit

class CreateMosaicViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var sizeSlider: UISlider!
    @IBOutlet weak var qualitySlider: UISlider!
    @IBOutlet weak var goButton: UIButton!
    
    var image: UIImage!
    var mosaicCreator: MosaicCreator!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.contentMode = UIViewContentMode.scaleAspectFit // 图片填充模式
        imageView.image = image
        goButton.isHidden = true
        // 3.传递图片进行预处理 马赛克制作---------------------------------------------
        mosaicCreator = MosaicCreator(reference: image)

        do {
            //如果预处理完成就显示goButton
            try mosaicCreator.preprocess(complete: {
                self.goButton.isHidden = false
            })
        } catch {
            print("预处理出错.")
        }

        // 网格和质量滑块设置最大最小值 默认值
        sizeSlider.minimumValue = Float(MosaicCreationConstants.gridSizeMin)
        sizeSlider.maximumValue = Float(MosaicCreationConstants.gridSizeMax)
        qualitySlider.minimumValue = Float(MosaicCreationConstants.qualityMin)
        qualitySlider.maximumValue = Float(MosaicCreationConstants.qualityMax)

        let sizeSliderDefault = Float(MosaicCreationConstants.gridSizeMax - MosaicCreationConstants.gridSizeMin)/2
        let qualitySliderDefault = Float(MosaicCreationConstants.qualityMax - MosaicCreationConstants.qualityMin)/2

        sizeSlider.value = sizeSliderDefault
        qualitySlider.value = qualitySliderDefault

        
        // 传递滑块默认值
        mosaicCreator.setQuality(Float(qualitySliderDefault))
        mosaicCreator.setGridSizePoints(Int(sizeSliderDefault))
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // 网格大小改变
    @IBAction func sizeChanged(_ sender: UISlider) {
        let value = Int(sender.value)
        mosaicCreator.setGridSizePoints(value)
        print(Int(sender.value))
    }
    
    // 图片质量改变
    @IBAction func qualityChanged(_ sender: UISlider) {
        let value = Float(sender.value)
        mosaicCreator.setQuality(value)
        print(Float(sender.value))
    }
    
    
    // 创造合成图片
    @IBAction func creatCompositePhoto(_ sender: Any) {
        
    }
    
    @IBAction func unwindToCreateMosaic(segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "CreateMosaicToCompositePhoto" {
            mosaicCreator = MosaicCreator(reference: image.scaleImage(scaleSize: CGFloat(self.qualitySlider.value)))
            if let compositePhotoViewController = segue.destination as? CompositePhotoViewController {
                compositePhotoViewController.mosaicCreator = mosaicCreator
            }
        }
    }
}
