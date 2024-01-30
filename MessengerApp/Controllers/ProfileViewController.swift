//
//  ProfileViewController.swift
//  MessengerApp
//
//  Created by Smruthi Pobbathi on 12/5/23.
//

import UIKit
import FirebaseAuth
import FacebookLogin
import GoogleSignIn
import SDWebImage

final class ProfileViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    var data = [ProfileViewModel]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        data.append(ProfileViewModel(profileViewModelType: .info,
                                     title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")",
                                     handler: nil))
        data.append(ProfileViewModel(profileViewModelType: .info,
                                     title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")",
                                     handler: nil))
        data.append(ProfileViewModel(profileViewModelType: .logout, title: "Log Out", handler: {[weak self] in
            guard let strongSelf = self else {
                return
            }
            let actionSheet = UIAlertController(title: "",
                                          message: "",
                                          preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "Log out",
                                           style: .destructive,
                                                 handler: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                UserDefaults.standard.set(nil, forKey: "email")
                UserDefaults.standard.set(nil, forKey: "name")
                
                // log out facebook
                FacebookLogin.LoginManager().logOut()
                
                // log out of google
                GIDSignIn.sharedInstance.signOut()
                
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    
                    if FirebaseAuth.Auth.auth().currentUser == nil {
                        let vc = LoginViewController()
                        let nav = UINavigationController(rootViewController: vc)
                        nav.modalPresentationStyle = .fullScreen
                        strongSelf.present(nav, animated: true)
                    }
                } catch {
                    print("Failed to logout")
                }
                
            }))
            
            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            strongSelf.present(actionSheet, animated: true)
        }))
        
        tableView.register(ProfileTableViewCell.self,
                           forCellReuseIdentifier: "ProfileTableViewCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
    }
    
    func createTableHeader() -> UIView? {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_picture.png"
        
        let path = "images/" + fileName
        
        let headerView = UIView(frame: CGRect(x: 0,
                                        y: 0,
                                        width: view.width,
                                        height: 300))
        
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(frame: CGRect(x: (headerView.width - 150) / 2,
                                                  y: 75,
                                                  width: 150,
                                                  height: 150))
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        
        headerView.addSubview(imageView)
        
        StorageManager.shared.downoadUrl(for: path, completion: { result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url)
            case .failure(let error):
                print("failed to get download url: \(error)")
            }
        })
        return headerView
    }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileTableViewCell", for: indexPath) as! ProfileTableViewCell
        cell.setUp(with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }
}
