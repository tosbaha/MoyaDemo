//
//  UserService.swift
//  MoyaDemo
//
//  Created by Mustafa on 11/8/17.
//  Copyright © 2017 Mustafa. All rights reserved.
//

import Foundation

class UserService {
    static let sharedInstance = UserService()
    var user:User?
    
    init() {
        let user = User(email: "some@domain.com", password: "somepassword", token: "oldToken")
        self.user = user
    }
    
    func getUser() -> User? {
        return user
    }
    
    class func logOut() throws {
        sharedInstance.user?.token = "oldToken"
    }
}

struct User {
    var email:String
    var password:String
    var token:String
    
}

struct Token:Codable {
    var token:String
    
    func saveInRealm() throws{
        UserService.sharedInstance.user?.token = self.token
        print("Token is saved")
    }
}

struct Post:Codable {
    var id:Int
    var title:String
    var subtitle:String
}
