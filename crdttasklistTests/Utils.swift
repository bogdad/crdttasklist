//
//  Utils.swift
//  crdttasklistTests
//
//  Created by Vladimir on 2020-02-08.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation
import XCTest

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

    static func saveToFile<T: Codable>(obj: T, url: URL) {
        let data = try! PropertyListEncoder().encode(obj)
        let dataWriter = try! NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false)
        try! dataWriter.write(to: url)
    }

    static func loadFromFile<T: Codable>(type: T.Type, url: URL) -> T {
        let loadData = NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? Data
        let fileObj = try! PropertyListDecoder().decode(type, from: loadData!)
        return fileObj
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
        Utils.saveToFile(obj: obj, url: url)
        return Utils.loadFromFile(type: T.self, url: url)
    }
}
