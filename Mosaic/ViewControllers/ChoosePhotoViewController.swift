//
//  ChoosePhotoViewController.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import UIKit
import Metal

class ChoosePhotoViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    // The Metal device we use to perform Metal operations
    var pickedImage: UIImage!
    var imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // 相册库中选择相片
    @IBAction func chooseImage(_ sender: UIButton) {
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            print("Photo Capture")
            
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.isEditing = false
//            imagePicker.
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    // 摄像头拍摄获得相片
    @IBAction func takePicture(_ sender: UIButton) {
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            print("Camera Capture")
            
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            imagePicker.isEditing = false
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    // 退出选择相片界面 获得相片则转场
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if (info[UIImagePickerControllerOriginalImage]) != nil {
            pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage 
            dismiss(animated: true, completion: {
                self.performSegue(withIdentifier: "ChoosePhotoToCreateMosaic", sender: self)
            })
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func unwindBackToChoosePhoto(for: UIStoryboardSegue, sender: Any?) {
        
    }
    
    // 转场传递图片
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ChoosePhotoToCreateMosaic" {
            if let CreatMosaicViewContorller = segue.destination as? CreateMosaicViewController {
                CreatMosaicViewContorller.image = pickedImage.scaleImage(scaleSize: 2.0)
            }
        }
    }
    
    
}

extension UIImage {
    func YhyReSizeImage(reSize:CGSize)->UIImage {
        
        //UIGraphicsBeginImageContext(reSize);
        
        UIGraphicsBeginImageContextWithOptions(reSize,false,UIScreen.main.scale);
        
        self.draw(in: CGRect(x: 0, y: 0, width: reSize.width, height: reSize.height))
        
        let reSizeImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!;
        
        UIGraphicsEndImageContext();
        
        return reSizeImage;
        
    }
    
    func scaleImage(scaleSize:CGFloat)->UIImage {
        
        let reSize = CGSize(width: self.size.width * scaleSize, height: self.size.height * scaleSize)
        
        return YhyReSizeImage(reSize: reSize)
        
    }
}
