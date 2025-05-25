//
//  MusicCell.swift
//  CarPlayTest1
//
//  Created by Amerigo Mancino on 15/11/22.
//

import UIKit

class MusicCell: UITableViewCell {
    
    @IBOutlet weak var authorImage: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var author: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
