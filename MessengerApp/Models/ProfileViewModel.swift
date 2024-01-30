//
//  ProfileViewModel.swift
//  MessengerApp
//
//  Created by Smruthi Pobbathi on 1/29/24.
//

import Foundation

enum ProfileViewModelType {
    case info
    case logout
}
struct ProfileViewModel {
    let profileViewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
 
