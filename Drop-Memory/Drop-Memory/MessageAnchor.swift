//
//  MessageAnchor.swift
//  Drop-Memory
//
//  Created by David Minders on 4/5/19.
//  Copyright © 2019 DVT. All rights reserved.
//

import Foundation

struct MessageAnchor {
    var ID: UUID
    var message: String
    
    init(id: UUID, message: String) {
        self.ID = id
        self.message = message
    }
}
