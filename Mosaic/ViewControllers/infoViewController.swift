//
//  infoViewController.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/23.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import UIKit

class infoViewController: UIViewController {

    @IBOutlet weak var infoTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.infoTextView.text = NSLocalizedString("info", comment: "info")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    

}
