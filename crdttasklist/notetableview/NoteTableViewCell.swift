//
//  NoteTableViewCell.swift
//  crdttasklist
//
//  Created by Vladimir Shakhov on 10/4/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//

import Foundation
import UIKit

class NoteTableViewCell: UITableViewCell {

  @IBOutlet weak var nameLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
  }

  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
  }

  func setIntensity(_ note: Note) {
    let base = note.baseIntensity()
    let int1 = note.intensity1()
    let int2 = note.intensity2()
    if int1 > 0 && int2 > 0 {
      backgroundColor = UIColor.systemRed.withAlphaComponent(CGFloat((0.1 + int1 + int2) * base))
    } else if int1 > 0 {
      backgroundColor = UIColor.systemPink.withAlphaComponent(CGFloat((0.1 + int1) * base))
    } else if int2 > 0 {
      backgroundColor = UIColor.systemOrange.withAlphaComponent(CGFloat((0.1 + int2) * base))
    } else {
      backgroundColor = Design.grayBackround()
    }
  }

}
