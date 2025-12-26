//
//  CurrentUserService.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import Foundation

class CurrentUserService {
    static let shared = CurrentUserService()

    private let userIdKey = "com.shawnschwartz.clementime.currentUserId"

    private init() {}

    var currentUserId: UUID {
        get {
            // Try to get existing user ID from UserDefaults
            if let uuidString = UserDefaults.standard.string(forKey: userIdKey),
               let uuid = UUID(uuidString: uuidString) {
                return uuid
            }

            // If no user ID exists, create a new one and save it
            let newUserId = UUID()
            UserDefaults.standard.set(newUserId.uuidString, forKey: userIdKey)
            return newUserId
        }
        set {
            UserDefaults.standard.set(newValue.uuidString, forKey: userIdKey)
        }
    }

    var currentUser: TAUser? {
        get {
            // Try to load current user from UserDefaults
            if let data = UserDefaults.standard.data(forKey: "com.shawnschwartz.clementime.currentUser") {
                return try? JSONDecoder().decode(TAUser.self, from: data)
            }
            return nil
        }
        set {
            if let user = newValue {
                let data = try? JSONEncoder().encode(user)
                UserDefaults.standard.set(data, forKey: "com.shawnschwartz.clementime.currentUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "com.shawnschwartz.clementime.currentUser")
            }
        }
    }

    func setCurrentUser(_ user: TAUser) {
        currentUserId = user.id
        currentUser = user
    }

    func clearCurrentUser() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: "com.shawnschwartz.clementime.currentUser")
    }
}
