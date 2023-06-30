//
//  PybeRequests.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 5/6/23.
//

import Foundation
import SwiftUI


class PybeRequests: ObservableObject {
    
    @State var isGroupMessage = false
    
    func getChatHistoryForUser(userID: String, bearerToken: String, completionHandler: @escaping ([[String: String]]?, Error?) -> Void) {
        let url = URL(string: "https://doc-gpt-app.azurewebsites.net/get-chat-history")!
        var request = URLRequest(url: url)
        
        request.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonBody = ["user_id": userID]
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody)
        
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            
            guard let data = data else {
                completionHandler(nil, nil)
                return
            }
            
            do {
                let responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let chatHistory = responseJSON?["chat_history"] as? [[String: String]] else {
                    completionHandler(nil, NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Response could not be parsed as chat history"]))
                    return
                }
                completionHandler(chatHistory, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
        
        task.resume()
    }
    
    func getChatHistoryForGroup(groupID: String, bearerToken: String, completionHandler: @escaping ([[String: String]]?, Error?) -> Void) {
        let url = URL(string: "https://doc-gpt-app.azurewebsites.net/get-chat-history-for-group")!
        var request = URLRequest(url: url)
        
        request.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonBody = ["group_id": groupID]
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody)
        
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            
            guard let data = data else {
                completionHandler(nil, nil)
                return
            }
            
            do {
                let responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let chatHistory = responseJSON?["chat_history"] as? [[String: String]] else {
                    completionHandler(nil, NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Response could not be parsed as chat history"]))
                    return
                }
                completionHandler(chatHistory, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
        task.resume()
    }
    
    
    func updateChatHistory(userID: String, groupID: String = "", chatHistory: [[String: String]], bearerToken: String, completionHandler: @escaping (Bool, Error?) -> Void) {
        
        let url: URL
        if !groupID.isEmpty {
            url = URL(string: "https://doc-gpt-app.azurewebsites.net/update-chat-history-for-group")!
        } else {
            url = URL(string: "https://doc-gpt-app.azurewebsites.net/update-chat-history")!
        }
        var request = URLRequest(url: url)
        
        request.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        
        let requestBody: [String: Any]
        if !groupID.isEmpty {
            requestBody = [
                "group_id": groupID,
                "chat_history": chatHistory
            ]
        } else {
            requestBody = [
                "user_id": userID,
                "chat_history": chatHistory
            ]
        }
        
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completionHandler(false, error)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(false, error)
                return
            }
            
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let message = json["message"] as? String {
                    print("Response message: \(message)")
                }
            }
            
            
            guard let response = response as? HTTPURLResponse else {
                completionHandler(false, nil)
                return
            }
            
            if response.statusCode == 200 {
                completionHandler(true, nil)
                
            } else {
                completionHandler(false, NSError(domain: "HTTPError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP request failed with status code \(response.statusCode)"]))
            }
        }
        
        task.resume()
    }
    
    func retrieveGroupsForUser(userID: String, bearerToken: String, completionHandler: @escaping ([Group]?, Error?) -> Void) {
        let url = URL(string: "https://doc-gpt-app.azurewebsites.net/get-groups-for-user")!
        var request = URLRequest(url: url)
        
        // Add bearer token to request headers
        request.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        // Set request method and content type
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Construct JSON body
        let jsonBody = ["user_id": userID]
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody)
        
        // Add JSON body to request
        request.httpBody = jsonData
        
        // Create and send URLSession data task
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            
            guard let data = data else {
                completionHandler(nil, nil)
                return
            }
            
          
                let decoder = JSONDecoder()
                
                    do {
                        let groups = try decoder.decode(Groups.self, from: data)
                        let finalGroups = groups.groups as [Group]
                        DispatchQueue.main.async {
                           completionHandler(finalGroups, nil)
                        }
                    } catch {
                        completionHandler(nil, error)
                    }
                    

        }
        
        task.resume()
    }
}
