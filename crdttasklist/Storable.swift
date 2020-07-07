//
//  Storable.swift
//  crdttasklist
//
//  Created by Vladimir on 2020-06-27.
//  Copyright © 2020 Vladimir Shakhov. All rights reserved.
//

import Foundation

protocol Storable {

  mutating func commitEvents(_ appState: AppState) -> [Event]
}
