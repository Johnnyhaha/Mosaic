//
//  Preprocessing.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/11.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation
import Photos

enum LibraryProcessingError: Error {
    case PreprocessingInProgress
    case LibraryAccessIssue
}

protocol PhotoProcessor {
    init(timer: MosaicCreationTimer)
    var threadWidth: Int { get set }
    func preprocess(complete : @escaping () -> Void) throws -> Void
    func preprocessProgress() -> Int
    
    func findNearestMatch(tpa: TenPointAverage) -> (String, Float)?
    func processPhoto(image: CGImage, synchronous: Bool, complete: @escaping (TenPointAverage?) throws -> Void) -> Void
    func progress() -> Int
}
