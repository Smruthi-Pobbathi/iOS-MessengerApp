//
//  ChatViewController.swift
//  MessengerApp
//
//  Created by Smruthi Pobbathi on 12/7/23.
//

import UIKit
import MessageKit

struct Message: MessageType {
    
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
}

struct Sender: SenderType {
    
    var photoURL: String
    var senderId: String
    var displayName: String
}

class ChatViewController: MessagesViewController {
    
    private var messages = [Message]()
    
    private let selfSender = Sender(photoURL: "",
                                    senderId: "1",
                                    displayName: "Joe Smith")
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        messages.append(Message(sender: selfSender,
                                messageId: "1",
                                sentDate: Date(),
                                kind: .text("Hello world message")))
        
        messages.append(Message(sender: selfSender,
                                messageId: "1",
                                sentDate: Date(),
                                kind: .text("Hello world message. Hello world message. Hello world message")))
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.reloadData()
        
        // configureUI()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        configureLayouts()
    }
    
    func configureUI() {
       
    }
    
    func configureLayouts() {
//        MessagesCollectionView(frame: .zero)
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    
    var currentSender: SenderType {
        return selfSender
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        print(messages[indexPath.section])
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
}
