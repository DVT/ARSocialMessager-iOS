//
//  MeetingRoomModel.swift
//  Drop-Memory
//
//  Created by Prateek Kambadkone on 2019/04/12.
//  Copyright © 2019 DVT. All rights reserved.
//

import Foundation

struct MeetingRoom {
    let title: String
    let desc: String
    let slots: [Booking]
    let imageName: String
}

struct Booking {
    let time: String
    let bookedBy: String
}


