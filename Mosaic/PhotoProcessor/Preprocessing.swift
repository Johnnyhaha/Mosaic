//
//  Preprocessing.swift
//  Mosaic
//
//  Created by Johnny_L on 2017/11/11.
//  Copyright © 2017年 Johnny_L. All rights reserved.
//

import Foundation

enum LibraryPreprocessingError: Error {
    case PreprocessingInProgress
    case LibraryAccessIssue
}

protocol LibraryPreprocessing {
    func begin(complete: @escaping() -> Void) throws -> Void
    func progress() -> Int
}
