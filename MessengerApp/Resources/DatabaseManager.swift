//
//  DatabaseManager.swift
//  MessengerApp
//
//  Created by Smruthi Pobbathi on 12/6/23.
//

import Foundation
import FirebaseDatabase
import MessageKit
import UIKit
import CoreLocation

public enum DatabaseError: Error {
    case failedToFetch
}

/// Manager object to read and write data to real time firebase database
final class DatabaseManager {
    
    /// Shared instance of class
    public static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager {
    
    /// Returns dictionary node for child path
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}

//MARK: - Account Management

extension DatabaseManager {
    
    /// Checks if user exists for a given email
    /// Parameters
    ///  - `email`:           Target email to be checked
    ///  - `completion`:   Async closure to return with result
    public func userExists(with email: String, completion: @escaping((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String : Any] != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Inserts  new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        
        // making the root entry and making sure nothing went wrong
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { [weak self] error, _ in 
            guard error == nil else {
                print("failed to write to database")
                completion(false)
                return
            }
            
            /*
             users => [
             [
             "name":
             "safeEmail":
             
             ],
             [
             "name":
             "safeEmail":
             
             ],
             ]
             */
            // add it to our array of users. check if coolection exists or else create
            self?.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var usersCollection = snapshot.value as? [[String : String]] {
                    // append to user dictionary
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    
                    usersCollection.append(newElement)
                    self?.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                    
                } else {
                    // create array
                    let newCollection: [[String : String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    self?.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    /// Gets all users from database
    public func getAllUsers(completion: @escaping (Result<[[String : String]], Error>) -> Void) {
        
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String:String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
        
        public var localizedDescription: String {
            switch self {
            case .failedToFetch:
                return "This means blah failed"
            }
        }
    }
}

// MARK: - Sending messages / conversations

extension DatabaseManager {
    
    /*
     "sadasdasdfa" {
        "messages": [
            {
                "id": String,
                "type": text, photo, video,
                "content": text/photourl,
                "date": Date(),
                "sender_email": String,
                "is_read": true/false
            }
        ]
     }
     
     conversation => [
        [
            "conversation_id": "sadasdasdfa"
            "other_user_email":
            "latest_message": => {
                "date":Date()
                "latest_message": "message"
                "is_read": true/false
     
        ],
         [
             "conversation_id":
             "other_user_email":
             "latest_message": => {
                 "date":Date()
                 "latest_message": "message"
                 "is_read": true/false
            }
      
         ],
     ]
     */
    
    /// Create a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String
        else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String:Any] else {
                completion(false)
                print("User not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_), .photo(_), .video(_), .location(_), .emoji(_), .audio(_), .contact(_), .linkPreview(_), .custom(_):
                break
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            // Update recipient conversaiton entry

             self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                 if var conversations = snapshot.value as? [[String: Any]] {
                     // append
                     conversations.append(recipient_newConversationData)
                     self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                 }
                 else {
                     // create
                     self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                 }
             })
           
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for current user
                // you should append
                
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name,
                                                     conversationId: conversationId,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                })
                
            } else {
                // conversation array does not exist
                // create new it
                
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(name: name,
                                                    conversationId: conversationId,
                                                    firstMessage: firstMessage,
                                                    completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation( name: String, conversationId: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
        /*
         "sadasdasdfa" {
            "messages": [
                {
                    "id": String,
                    "type": text, photo, video,
                    "content": text/photourl,
                    "date": Date(),
                    "sender_email": String,
                    "is_read": true/false
                }
            ]
         }
         */
        
        guard let myEmail  = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        switch firstMessage.kind {
            
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        
        ]
        
        print("adding convo: \(value)")
        
        database.child("\(conversationId)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String : Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                        return nil
                }
                
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        is_read: isRead)
                
                return Conversation(id: conversationId,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            })
            
            completion(.success(conversations))
        })
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageId = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let type = dictionary["type"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                          return nil
                      }
                
                
                var kind: MessageKind?
                
                if type == "photo" {
                    // photo
                    guard let imageUrl = URL(string: content),
                          let placeHolder = UIImage(systemName: "plus")  else {
                        return nil
                    }
                    let media = Media(url: imageUrl,
                                      image: nil,
                                      placeholderImage: placeHolder,
                                      size: CGSize(width: 300, height: 300))
                    
                    kind = .photo(media)
                } else if type == "video" {
                    // video
                    guard let videoUrl = URL(string: content),
                          let placeHolder = UIImage(named: "placeholderPlay")  else {
                        return nil
                    }
                    let media = Media(url: videoUrl,
                                      image: nil,
                                      placeholderImage: placeHolder,
                                      size: CGSize(width: 300, height: 300))
                    
                    kind = .video(media)
                    
                } else if type == "location" {
                    let locationComponenets = content.components(separatedBy: ",")
                    
                    guard let longitude = Double(locationComponenets[0]),
                          let latitude = Double(locationComponenets[1]) else {
                        return nil
                    }
                    print("rendering location long = \(longitude), lat = \(latitude)")
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: CGSize(width: 300, height: 300))
                    kind = .location(location)
                    
                } else {
                    kind = .text(content)
                }
                
                guard let finalKind = kind else {
                    return nil
                }
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                
                return Message(sender: sender,
                               messageId: messageId,
                               sentDate: date,
                               kind: finalKind)
                        
            })
            completion(.success(messages))
        })
        
    }
    
    /// sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        // Add new message to messages
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            
            guard let strongSelf = self else {
                return
            }
            
            guard var currentMessages = snapshot.value as?  [[String : Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch newMessage.kind {
                
            case .text(let messageText):
                message = messageText
                
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
                break
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
                break
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                break
            case .attributedText(_), .emoji(_), .audio(_),  .contact(_), .linkPreview(_), .custom(_):
                break
            }
            
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                
                guard error == nil else {
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue : [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String: Any]]  {
                        // we need to create conversation entry
                        
                        // Find the entry of current conversation ID and update the latest message
                        
                        var targetConversation: [String:Any]?
                        
                        var position = 0
                        
                        for conversationDictionary in currentUserConversations {
                            if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                // update the latest message
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }
                        if var targetConversation = targetConversation {
                            
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else
                        {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
              
                    } else {
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                           newConversationData
                        ]
                    }

                    strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        // Update latest message for recipient user
                        
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            
                            var databaseEntryConversations = [[String: Any]]()
                            let updatedValue : [String: Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]
                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                                return
                            }
                            
                            if var otherUserConversations = snapshot.value as? [[String: Any]]  {
                                
                                // Find the entry of current conversation ID and update the latest message
                           
                                var targetConversation: [String:Any]?
                                
                                var position = 0
                                
                                for conversationDictionary in otherUserConversations {
                                    if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                        // update the latest message
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                }
                                if var targetConversation = targetConversation{
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                } else {
                                    // failed to find in current collection
                                    let newConversationData: [String: Any] = [
                                        "id": conversation,
                                        "other_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                        "name": currentName,
                                        "latest_message": updatedValue
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                    
                                }
                        
                            } else {
                                // current collection does not exist
                                let newConversationData: [String: Any] = [
                                    "id": conversation,
                                    "other_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                    "name": currentName,
                                    "latest_message": updatedValue
                                ]
                                databaseEntryConversations = [
                                   newConversationData
                                ]
                            }
                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                
                                completion(true)
                            })
                        })
                    })
                })
            }
        })
        
        // update sender latest message
        // update recipient latest message
    }
    
    public func deleteConversation(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        print("Deleting conversation with id: \(conversationId)")
        
        // Get conversations for current user
        // Delete conversation in collection with target id
        // reset those conversations for the user in database
        
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value, with: { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String, id == conversationId {
                        print("Found conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        completion(false)
                        print("Failed to write new conversation array")
                        return
                    }
                    print("Deleted conversation")
                    completion(true)
                })
            }
        })
    }
    
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping ((Result<String,Error>) -> Void)) {
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
            guard let collection = snapshot.value as? [[String:Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            // Iterate and find conversation with target sender
            
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // get id
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
}


struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    // computed property
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String {
        //smruthi096-gmail-com_profile_picture.png
        return "\(safeEmail)_profile_picture.png"
    }
}
