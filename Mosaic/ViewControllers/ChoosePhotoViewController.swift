//
//  ChoosePhotoViewController.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/9.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import UIKit
import Metal

var loadedFromFile : Bool = false

class ChoosePhotoViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    var pickedImage: UIImage!
    var imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func newPreprocessButton(_ sender: UIButton) {
        loadedFromFile = true
    }
    
    
    // 相册库中选择相片
    @IBAction func chooseImage(_ sender: UIButton) {
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            print("相片捕获")
            
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.isEditing = false
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    // 摄像头拍摄获得相片
    @IBAction func takePicture(_ sender: UIButton) {
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            print("相机捕获")
            
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
    
    
    // 转场传递图片
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ChoosePhotoToCreateMosaic" {
            if let CreatMosaicViewContorller = segue.destination as? CreateMosaicViewController {
                CreatMosaicViewContorller.image = pickedImage
            }
        }
    }
    
    
    @IBAction func feedbackButton(_ sender: UIButton) {
        let alertController = UIAlertController(title: "FeedBack", message: nil, preferredStyle: .actionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let weiboAction = UIAlertAction(title: "Weibo", style: .default) { (action) in
            if let url = URL(string: "https://weibo.com/mygroups?gid=3725055240034717&wvr=6&leftnav=1&isspecialgroup=1") {
                //根据iOS系统版本，分别处理
                if #available(iOS 10, *) {
                    UIApplication.shared.open(url, options: [:],
                                              completionHandler: {
                                                (success) in
                    })
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }
        alertController.addAction(weiboAction)
        
        let twitterAction = UIAlertAction(title: "Twitter", style: .default) { (action) in
            if let url = URL(string: "https://twitter.com/BFLDW") {
                //根据iOS系统版本，分别处理
                if #available(iOS 10, *) {
                    UIApplication.shared.open(url, options: [:],
                                              completionHandler: {
                                                (success) in
                    })
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }
        alertController.addAction(twitterAction)
        
        alertController.popoverPresentationController?.sourceView = sender
        
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func likeButton(_ sender: UIButton) {
        if let url = URL(string: "https://itunes.apple.com/cn/app/Mosaic/id?mt=8") {
            //根据iOS系统版本，分别处理
            if #available(iOS 10, *) {
                UIApplication.shared.open(url, options: [:],
                                          completionHandler: {
                                            (success) in
                })
            } else {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    
}

