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
    
    private func buildRequestWithUrl(url: URL, bearerToken: String, requestBody: [String:Any]) -> URLRequest {
        var request = URLRequest(url: url)
        
        request.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try? JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        return request
    }
    
    private func handleArrayResponse(data: Data?, error: Error?, key: String, completionHandler: @escaping ([[String: String]]?, Error?) -> Void) {
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
            guard let arrayData = responseJSON?[key] as? [[String: String]] else {
                completionHandler(nil, NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Response could not be parsed"]))
                return
            }
            completionHandler(arrayData, nil)
        } catch {
            completionHandler(nil, error)
        }
    }
    
    private func handleStatusResponse(data: Data?, response: URLResponse?, error: Error?, completionHandler: @escaping (Bool, Error?) -> Void) {
        if let error = error {
            completionHandler(false, error)
            return
        }
        
        guard let response = response as? HTTPURLResponse else {
            completionHandler(false, nil)
            return
        }
        
        if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let message = json["message"] as? String {
                print("Response message: \(message)")
            }
        }
        
        if response.statusCode == 200 {
            completionHandler(true, nil)
        } else {
            completionHandler(false, NSError(domain: "HTTPError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP request failed with status code \(response.statusCode)"]))
        }
    }
    
    func getChatHistoryForUser(userID: String, bearerToken: String, completionHandler: @escaping ([[String: String]]?, Error?) -> Void) {
        let url = URL(string: "https://doc-gpt-app.azurewebsites.net/get-chat-history")!
        let jsonBody = ["user_id": userID]
        let request = buildRequestWithUrl(url: url, bearerToken: bearerToken, requestBody: jsonBody)
        
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            self.handleArrayResponse(data: data, error: error, key: "chat_history", completionHandler: completionHandler)
        }
        task.resume()
    }
    
    func getChatHistoryForGroup(groupID: String, bearerToken: String, completionHandler: @escaping ([[String: String]]?, Error?) -> Void) {
        let url = URL(string: "https://doc-gpt-app.azurewebsites.net/get-chat-history-for-group")!
        let jsonBody = ["group_id": groupID]
        var request = buildRequestWithUrl(url: url, bearerToken: bearerToken, requestBody: jsonBody)
        
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            self.handleArrayResponse(data: data, error: error, key: "chat_history", completionHandler: completionHandler)
        }
        task.resume()
    }
    
    func clearChatHistoryForUser(userID: String, bearerToken: String, completionHandler: @escaping (Bool, Error?) -> Void) {
        let url = URL(string: "https://doc-gpt-app.azurewebsites.net/clear-chat-history")!
        let jsonBody = ["user_id": userID]
        var request = buildRequestWithUrl(url: url, bearerToken: bearerToken, requestBody: jsonBody)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleStatusResponse(data: data, response: response, error: error, completionHandler: completionHandler)
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
        var request = buildRequestWithUrl(url: url, bearerToken: bearerToken, requestBody: requestBody)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleStatusResponse(data: data, response: response, error: error, completionHandler: completionHandler)
        }
        task.resume()
    }
    
    func retrieveGroupsForUser(userID: String, bearerToken: String, completionHandler: @escaping ([Group]?, Error?) -> Void) {
        let url = URL(string: "https://doc-gpt-app.azurewebsites.net/get-groups-for-user")!
        let jsonBody = ["user_id": userID]
        var request = buildRequestWithUrl(url: url, bearerToken: bearerToken, requestBody: jsonBody)
        
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
