//
//  Utils.swift
//  crdttasklistTests
//
//  Created by Vladimir on 2020-02-08.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import XCTest
@testable import crdttasklist

class Utils {
    static func getTempFile() -> (URL, ()->Void) {
        let fileManager = FileManager.default
        let dir =  fileManager.temporaryDirectory
        let filename = UUID().uuidString
        let fileURL = dir.appendingPathComponent(filename)
        return (fileURL, { () in
            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                fatalError("Error while deleting temporary file: \(error)")
            }
        })
    }
}

extension XCTestCase {
    func getTempFile() -> URL {
        let (url, block) = Utils.getTempFile()
        addTeardownBlock { block() }
        return url
    }

    func saveThenLoad<T: Codable>(obj: T) -> T {
        let url = getTempFile()
        FileUtils.saveToFile(obj: obj, url: url)
        return FileUtils.loadFromFile(type: T.self, url: url)!
    }
}
