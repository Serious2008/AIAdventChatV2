//
//  BuggyAuthService.swift
//  Demo code with intentional issues for PR Analyzer
//

import Foundation

class AuthenticationService {
    var apiKey: String = ""  // SECURITY: Hardcoded secret!
    
    func login(username: String, password: String) -> Bool {
        // BUG: No input validation
        // BUG: Password sent in plain text
        let url = "http://api.example.com/login?user=\(username)&pass=\(password)"
        
        // BUG: Force unwrap can crash
        let request = URLRequest(url: URL(string: url)!)
        
        // BUG: No error handling
        let (data, _) = try! URLSession.shared.data(for: request)
        
        // BUG: Force unwrap JSON
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        return json["success"] as! Bool  // Another force unwrap
    }
    
    // BUG: No password hashing
    func savePassword(_ password: String) {
        UserDefaults.standard.set(password, forKey: "password")
    }
}
