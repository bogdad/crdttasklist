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
       backgroundColor = UIColor.systemPink.withAlphaComponent(255*CGFloat(note.intensity()))
    }

}
