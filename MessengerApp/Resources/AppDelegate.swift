//
//  AppDelegate.swift
//  MessengerApp
//
//  Created by Smruthi Pobbathi on 12/5/23.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import FacebookCore
import GoogleSignIn

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        FirebaseApp.configure()
        
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        configureGoogleSignIn()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // open fb signin url
        ApplicationDelegate.shared.application(app,
                                               open: url, 
                                               sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
                                               annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
        
        //open google signin url
        var handled: Bool = GIDSignIn.sharedInstance.handle(url)
        if handled {
          return true
        }
        return false
    }
    
    func configureGoogleSignIn() {
        
        GIDSignIn.sharedInstance.restorePreviousSignIn(completion: { user, error in
            if  error != nil || user == nil {
                print("Failed to sugn in with google: \(String(describing: error))")
            } else {
                guard let userDetails = user,
                      let idToken = user?.idToken?.tokenString,
                      let email = user?.profile?.email,
                      let firstName = user?.profile?.givenName,
                      let lastName = user?.profile?.familyName
                else { return }
                
                print("Did sign in with google: \(userDetails)")
                
                DatabaseManager.shared.userExists(with: email, completion: { exists in
                    if !exists {
                        // insert to database
                        DatabaseManager.shared.insertUser(with: ChatAppUser(firstName: firstName,
                                                                            lastName: lastName,
                                                                            emailAddress: email))
                    }
                })
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                               accessToken: userDetails.accessToken.tokenString)
                FirebaseAuth.Auth.auth().signIn(with: credential, completion: { authResult, error in
                    guard authResult != nil, error == nil else {
                        print("Failed to login with google credential")
                        return
                    }
                    print("Successfully signed in with google credential")
                    NotificationCenter.default.post(name: .didLoginNotification, object: nil)
                })
            }
     })
    }
}
