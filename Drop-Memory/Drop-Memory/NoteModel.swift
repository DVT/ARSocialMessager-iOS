//
//  NoteType.swift
//  Drop-Memory
//
//  Created by Prateek Kambadkone on 2019/04/12.
//  Copyright © 2019 DVT. All rights reserved.
//

import Foundation

struct Note {
    enum NoteType {
        case Meeting
        case Info
        case Office
    }
    
    enum MeetingType {
        case lollipop
        case ctrl
        case alt
        case del
        case not
    }
    
    enum InfoType {
        case aircon
        case vendingMachine
        case hangers
        case firstAid
        case not
    }
    
    enum OfficeType {
        case office1
        case office2
        case not
    }
    
    let noteType: NoteType
    let meetingRoom: MeetingType
    let infoType: InfoType
    let office: OfficeType
}







