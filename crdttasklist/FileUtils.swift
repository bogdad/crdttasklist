//
//  Utils.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-02-08.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

class FileUtils {
    static func saveToFile<T: Codable>(obj: T, url: URL) {
        let data = try! PropertyListEncoder().encode(obj)
        let dataWriter = try! NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false)
        try! dataWriter.write(to: url)
    }

    static func loadFromFile<T: Codable>(type: T.Type, url: URL) -> T? {
        guard let loadData = NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? Data else {
            return nil
        }
        let fileObj = try? PropertyListDecoder().decode(type, from: loadData)
        return fileObj
    }
}
