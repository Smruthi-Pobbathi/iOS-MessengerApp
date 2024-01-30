//
//  ConversationModels.swift
//  MessengerApp
//
//  Created by Smruthi Pobbathi on 1/29/24.
//

import Foundation

struct Conversation {
    let id: String
    let name: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    let is_read: Bool
}
