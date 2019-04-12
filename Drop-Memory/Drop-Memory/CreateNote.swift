//
//  CreateNotes.swift
//  Drop-Memory
//
//  Created by Prateek Kambadkone on 2019/04/12.
//  Copyright © 2019 DVT. All rights reserved.
//

import Foundation
import ARKit

class CreateNote {
    
    var displayScene: SKScene? = nil
    var note: Note!
//    var title: String!
//    var desc: String!
//    var author: String!
    
    required init(type: Note) { //, title: String, desc: String, author: String) {
        note = type
//        self.title = title
//        self.desc = desc
//        self.author = author
        createScene()
    }
    
    func createScene() {
        var isValidType = true
        switch note.noteType {
        case .Meeting:
            displayScene = SKScene(fileNamed: "MeetingTemplate")
            switch note.meetingRoom {
            case .lollipop:
                setMeetingRoomDetails(details: MeetingRoom(title: "Lollipop Room", desc: "Seats: 6", slots: [Booking(time: "11:00 - 12:30", bookedBy: "James"),
                                                                                             Booking(time: "13:00 - 14:00", bookedBy: "Rose"),
                                                                                             Booking(time: "09:00 - 10:00", bookedBy: "PJ")],
                                                           imageName: "Lollipop_Room"))
            case .ctrl:
                setMeetingRoomDetails(details: MeetingRoom(title: "Ctrl Room", desc: "Seats: 8", slots: [Booking(time: "08:00 - 09:30", bookedBy: "Rose"),
                                                                                                             Booking(time: "10:00 - 11:00", bookedBy: "PJ"),
                                                                                                             Booking(time: "13:00 - 14:00", bookedBy: "Ronnie")],
                                                           imageName: "Control_Room"))
            case .alt:
                setMeetingRoomDetails(details: MeetingRoom(title: "Alt Room", desc: "Seats: 4", slots: [Booking(time: "07:00 - 08:00", bookedBy: "Ronnie"),
                                                                                                             Booking(time: "08:00 - 10:00", bookedBy: "Theunis"),
                                                                                                             Booking(time: "11:00 - 12:00", bookedBy: "Saurabh")],
                                                           imageName: "Alt_Room"))
            case .del:
                setMeetingRoomDetails(details: MeetingRoom(title: "Del Room", desc: "Seats: 4", slots: [Booking(time: "09:00 - 10:30", bookedBy: "Ike"),
                                                                                                             Booking(time: "15:00 - 16:00", bookedBy: "Chris"),
                                                                                                             Booking(time: "07:00 - 07:30", bookedBy: "James")],
                                                           imageName: "Delete_Room"))
            case .not:
                isValidType = false
            }
            
        case .Info:
            displayScene = SKScene(fileNamed: "InfoTemplate")
            switch note.infoType {
            case .aircon:
                setInfoDetails(details: Info(title: "Aircon Remote", desc: ["- Should not be set below 25 \n- Switch off after 6pm \n \n"], setBy: "By: Management"))
            case .firstAid:
                setInfoDetails(details: Info(title: "First Aid Kit", desc: ["- Contact James if you're dying ☠️ and need the key \n 😷"], setBy: "By: Management"))
            case .vendingMachine:
                setInfoDetails(details: Info(title: "Vending Machine", desc: ["- For assistance with the vending machine contact Bongani \n- Only accepts R10 and R20 notes"], setBy: "By: Management"))
            case .hangers:
                setInfoDetails(details: Info(title: "Alien Contact \nDevice", desc: ["- Pull these buttons to call the 👽 aliens 👽 \n \n"], setBy: "By: James"))
            case .not:
                isValidType = false
            }
            
        case .Office:
            displayScene = SKScene(fileNamed: "OfficeTemplate")
            switch note.office {
            case .office1:
                setOfficeDetails(details: OfficeMembers(officeName: "HR Office", members: [Staff(name: "Jon", imageName: "Jon"),
                                                                                           Staff(name: "Daenerys", imageName: "Daenerys"),
                                                                                           Staff(name: "Jaime", imageName: "Jaime"),
                                                                                           Staff(name: "Tyrion", imageName: "Tyrion"),
                                                                                           Staff(name: "Bronn", imageName: "Bronn"),
                                                                                           Staff(name: "Cersei", imageName: "Cersei")]))
            case .office2:
                setOfficeDetails(details: OfficeMembers(officeName: "Admin Office", members: [Staff(name: "Tony", imageName: "rdj"),
                                                                                          Staff(name: "Steve", imageName: "captainAmerica"),
                                                                                          Staff(name: "Thor", imageName: "thor"),
                                                                                          Staff(name: "Natasha", imageName: "widow"),
                                                                                          Staff(name: "Peter", imageName: "spiderman"),
                                                                                          Staff(name: "Bruce", imageName: "hulk")]))
            case .not:
                isValidType = false
            }
        }
        
        if !isValidType {
            print("invalid selection: template not found!")
        }
    }
    
    private func setMeetingRoomDetails(details: MeetingRoom) {
        if let displayScene = displayScene {
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = details.title
            }
            
            if let desc = displayScene.childNode(withName: "Description") as? SKLabelNode {
                desc.text = details.desc
            }
            
            for i in 0..<details.slots.count {
                let timeTag = "Time\(i+1)"
                if let label = displayScene.childNode(withName: timeTag) as? SKLabelNode {
                    label.text = details.slots[i].time
                }
                
                if let label = displayScene.childNode(withName: "Name\(i+1)") as? SKLabelNode {
                    label.text = details.slots[i].bookedBy
                }
            }
            
            if let image = displayScene.childNode(withName: "Image") as? SKSpriteNode {
                image.texture = SKTexture(imageNamed: details.imageName)
            }
            displayScene.backgroundColor = .clear
        }
    }
    
    private func setInfoDetails(details: Info) {
        if let displayScene = displayScene {
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = details.title
            }
            
            if let info = displayScene.childNode(withName: "Info") as? SKLabelNode {
                info.text = details.desc[0]
                info.preferredMaxLayoutWidth = 350
            }
            
            if let setter = displayScene.childNode(withName: "Setter") as? SKLabelNode {
                setter.text = details.setBy
            }
            displayScene.backgroundColor = UIColor.transparentWhite
        }
    }
    
    private func setOfficeDetails(details: OfficeMembers) {
        if let displayScene = displayScene {
            if let title = displayScene.childNode(withName: "Title") as? SKLabelNode {
                title.text = details.officeName
            }
            
            for i in 0..<details.members.count {
                if let image = displayScene.childNode(withName: "Image\(i+1)") as? SKSpriteNode {
                    image.texture = SKTexture( image: UIImage(named: details.members[i].imageName)!.circleMasked! )
                }
                if let setter = displayScene.childNode(withName: "Name\(i+1)") as? SKLabelNode {
                    setter.text = details.members[i].name
                }
            }
             displayScene.backgroundColor = UIColor.transparentWhite
        }
    }
    
    func getScene() -> SKScene? {
        if let displayScene = displayScene {
            return displayScene
        }
        else {
            return nil
        }
    }
    
}
