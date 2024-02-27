//
//  ContentViewModel.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 4/30/23.
//

import Foundation
import SwiftUI
import AVKit
import PDFKit
import CoreData


class ContentViewModel: ObservableObject {
    @Published var isInteractingWithChatGPT = false
    @Published var messages: [MessageRow] = []
    @Published var inputMessage: String = ""
    @Published var navigationTitle = "Hunter"
    @Published var authenticator: Authenticator?
    @ObservedObject var pybeRequests = PybeRequests()
    var accessToken: String?
    var userID: String?
    var groupID: String?
    var givenName: String?
    
    private var synthesizer: AVSpeechSynthesizer?
    
    private let api: ChatGPTAPI
    
    init(api: ChatGPTAPI, enableSpeech: Bool = false) {
        self.api = api
        if enableSpeech {
            synthesizer = .init()
        }
    }
    
    @MainActor
    func sendTapped(shouldSendToChatGPT: Bool) async {
        let text = inputMessage
        inputMessage = ""
        if shouldSendToChatGPT {
            await send(text: text)
        } else {
            
            if let givenName = givenName {
                let message = MessageRow(isInteractingWithChatGPT: false, sendImage: givenName, sendText: text, responseImage: "")
                messages.append(message)
            }
            
            var chat = [[String: String]]()
            if let givenName = givenName {
                chat = [["message": text, "sender": givenName]]
            } else {
                print("couldnt find given name")
            }
            
            if let groupID = groupID, let userID = userID, let accessToken = accessToken {
                pybeRequests.updateChatHistory(userID: userID, groupID: groupID, chatHistory: chat, bearerToken: accessToken) { success, error in
                    if let error = error {
                        print(error)
                    } else {
                        print("SUCCCEESSSSSS")
                    }
                }
            }
        }
    }
    
    @MainActor
    func clearMessages() {
        stopSpeaking()
        api.deleteHistoryList()
        withAnimation { [weak self] in
            self?.messages = []
        }
    }
    
//    @MainActor
//    func uploadDocument(text: String) async {
//        let text = "Can you summarize the following document? \n" + text
//        await send(text: "Uploading Document...", documentText: text)
//    }
    
    @MainActor
    func retry(message: MessageRow) async {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }
        self.messages.remove(at: index)
        await send(text: message.sendText)
    }
    
    @MainActor
    private func send(text: String, documentText: String? = nil) async {
        let messageText = documentText ?? text
        isInteractingWithChatGPT = true
        var streamText = ""
        var messageRow = MessageRow(
            isInteractingWithChatGPT: true,
            sendImage: givenName!,
            sendText: text,
            responseImage: "openai",
            responseText: streamText,
            responseError: nil)
        
        self.messages.append(messageRow)
        
        do {
            if let accessToken = accessToken, let userID = userID, let givenName = givenName {
                if let groupID = groupID {
                    let stream = try await api.sendMessageStream(text: messageText, userID: userID, groupID: groupID, accessToken: accessToken, givenName: givenName, placeholderText: text)
                    for try await text in stream {
                        streamText += text
                        messageRow.responseText = streamText.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.messages[self.messages.count - 1] = messageRow
                    }
                } else {
                    let stream = try await api.sendMessageStream(text: messageText, userID: userID, accessToken: accessToken, givenName: givenName, placeholderText: text)
                    for try await text in stream {
                        streamText += text
                        messageRow.responseText = streamText.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.messages[self.messages.count - 1] = messageRow
                    }
                }
            }
            
        } catch {
            messageRow.responseError = error.localizedDescription
        }
        
        messageRow.isInteractingWithChatGPT = false
        self.messages[self.messages.count - 1] = messageRow
        isInteractingWithChatGPT = false
        speakLastResponse()
        
    }
    
    func speakLastResponse() {
        guard let synthesizer, let responseText = self.messages.last?.responseText, !responseText.isEmpty else {
            return
        }
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: responseText)
        utterance.voice = .init(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 0.8
        utterance.postUtteranceDelay = 0.2
        synthesizer.speak(utterance )
    }
    
    func stopSpeaking() {
        synthesizer?.stopSpeaking(at: .immediate)
    }
    
    func getChatHistoryForGroup(selectedGroup: Group, sceneDelegate: MainSceneDelegate) {
        guard let viewController = sceneDelegate.rootViewController else {
            preconditionFailure("missing root view controller")
        }
        
        let loadingVC = LoadingViewController(message: "Retrieving Chat History")
        
        DispatchQueue.main.async {
            viewController.present(loadingVC, animated: true, completion: nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let accessToken = self.accessToken else {
                print("Access token returned nil")
                return
            }
            self.pybeRequests.getChatHistoryForGroup(groupID: selectedGroup.id, bearerToken: accessToken) { response, error in
                if let error = error {
                    print("Error: \(error)")
                } else if let response = response {
                    var messages: [MessageRow] = []
                    for chat in response {
                        let message = chat["message"]
                        let sender = chat["sender"]
                        var image = String()
                        if sender == "chat-GPT" {
                            image = "openai"
                        } else {
                            image = sender!
                        }
                        let row = MessageRow(isInteractingWithChatGPT: false, sendImage: image, sendText: message!, responseImage: "")
                        messages.append(row)
                    }
                    DispatchQueue.main.async {
                        self.messages = messages
                        loadingVC.dismiss(animated: true)
                        self.navigationTitle = selectedGroup.name
                    }
                }
            }
        }
    }
    
    func getChatHistoryForUser(isFreshOpen: Bool, sceneDelegate: MainSceneDelegate, completion: @escaping() -> Void) {
        guard let accessToken = accessToken else {
            print("COULD NOT FIND ACCESSTOKEN")
            return
        }
        
        guard let userID = userID else {
            print("COULD NOT FIND USERID")
            return
        }
        
        guard let viewController = sceneDelegate.rootViewController else {
            preconditionFailure("missing root view controller")
        }
        
        let loadingVC = LoadingViewController(message: "Retrieving Chat History")
        
        if isFreshOpen == false {
            DispatchQueue.main.async {
                viewController.present(loadingVC, animated: true) {
                    self.pybeRequests.getChatHistoryForUser(userID: userID, bearerToken: accessToken) { response, error in
                        if let error = error {
                            print("Error: \(error)")
                        } else if let response = response {
                            var messages: [MessageRow] = []
                            for chat in response {
                                let message = chat["message"]
                                let sender = chat["sender"]
                                var image = String()
                                if sender == "chat-GPT" {
                                    image = "openai"
                                } else {
                                    image = sender!
                                }
                                let row = MessageRow(isInteractingWithChatGPT: false, sendImage: image, sendText: message!, responseImage: "")
                                messages.append(row)
                            }
                            DispatchQueue.main.async {
                                self.messages = messages
                                self.navigationTitle = "HUNTER"
                                loadingVC.dismiss(animated: true)
                            }
                        }
                    }
                }
            }
        } else {
            self.pybeRequests.getChatHistoryForUser(userID: userID, bearerToken: accessToken) { response, error in
                if let error = error {
                    print("Error: \(error)")
                } else if let response = response {
                    var messages: [MessageRow] = []
                    for chat in response {
                        let message = chat["message"]
                        let sender = chat["sender"]
                        var image = String()
                        if sender == "chat-GPT" {
                            image = "openai"
                        } else {
                            image = sender!
                        }
                        let row = MessageRow(isInteractingWithChatGPT: false, sendImage: image, sendText: message!, responseImage: "")
                        messages.append(row)
                    }
                    DispatchQueue.main.async {
                        self.messages = messages
                        self.navigationTitle = "HUNTER"
                        completion()
                    }
                }
            }
        }
        
        
        
        
    }
    
    func clearChatHistory(isGroupMessage: Bool) {
        if isGroupMessage {
            print("CLEAR CHAT HISTORY FOR GROUP")
        } else {
            if let userID = userID, let accessToken = accessToken {
                pybeRequests.clearChatHistoryForUser(userID: userID, bearerToken: accessToken) { _, error in
                    if let error = error {
                        print("HAD ERROR WHILE DELETING HISTORY \(error)")
                    } else {
                        DispatchQueue.main.async {
                            self.messages = []
                            print("SUCCESSFULLY DELETED HISTORY")
                        }
                    }
                }
            } else {
                print("COULD NOT CLEAR CHAT HISTORY")
            }
        }
    }
    
    func logIn(isFreshOpen: Bool, sceneDelegate: MainSceneDelegate, completion: @escaping() -> Void) {
        DispatchQueue.main.async {
            guard let viewController = sceneDelegate.rootViewController else {
                preconditionFailure("missing root view controller")
            }
            
            self.authenticator = Authenticator(view: viewController)
            self.authenticator?.baseAuth(completionHandler: { token, userID, givenName  in
                print("token is \(String(describing: token))")
                print("userID is \(String(describing: userID))")
                
                if let token = token, let userID = userID, let givenName = givenName {
                    self.accessToken = token
                    self.userID = userID
                    self.givenName = givenName
                    self.accessToken = token
                    self.userID = userID
                    self.givenName = givenName
                    self.getChatHistoryForUser(isFreshOpen: isFreshOpen, sceneDelegate: sceneDelegate) {
                        completion()
                    }
                }
            })
        }
    }
    
    func extractTextFromPDF(at pdfURL: URL) -> String? {
        guard pdfURL.startAccessingSecurityScopedResource() else {
            print("Error accessing security scoped resource.")
            return nil
        }
        defer { pdfURL.stopAccessingSecurityScopedResource() }
        
        guard let pdf = PDFDocument(url: pdfURL) else {
            return nil
        }
        var text = ""
        for pageIndex in 0 ..< pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else {
                continue
            }
            guard let pageContent = page.string else {
                continue
            }
            text += pageContent
        }
        return text
    }
    
    func uploadPDF(pdfURL: URL, completion: @escaping(Error?) -> Void) {
        // Ensure security-scoped resource access
        guard pdfURL.startAccessingSecurityScopedResource() else {
            print("Error accessing security scoped resource.")
            return
        }
        defer { pdfURL.stopAccessingSecurityScopedResource() }
        
        if let accessToken = accessToken {
            pybeRequests.uploadPdf(pdfURL: pdfURL, bearerToken: accessToken) { _, error in
                if let error = error {
                    print("HAD ERROR WHILE UPLOADING FILE \(error)")
                } else {
                    let documentName = pdfURL.deletingPathExtension().lastPathComponent
                    self.saveDocument(name: documentName, originalFilePath: pdfURL) {error in
                        if let error = error {
                            completion(error)
                        } else {
                            completion(nil)
                        }
                    }
                }
            }
        } else {
            print("COULD NOT UPLOAD FILE")
        }
    }
    
    func saveDocument(name: String, originalFilePath: URL, completion: @escaping (Error?) -> Void) {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Documents directory not found")
            return
        }

        guard originalFilePath.startAccessingSecurityScopedResource() else {
            print("Error accessing security scoped resource.")
            return
        }
        defer { originalFilePath.stopAccessingSecurityScopedResource() }
        // Create a new file name to avoid name conflicts
        let newFileName = UUID().uuidString + "-" + name
        let newFilePath = documentsDirectory.appendingPathComponent(newFileName)

        do {
            // Copy the file from the original location to the app's Documents directory
            try fileManager.copyItem(at: originalFilePath, to: newFilePath)
            print("File copied successfully to \(newFilePath.path)")

            // Save the new file path in Core Data
            let context = PersistenceController.shared.container.viewContext
            let newDocument = Document(context: context)
            newDocument.name = name
            newDocument.filePath = newFilePath.path // Save the path of the copied file
            newDocument.dateAdded = Date()
            
            try context.save()
            print("Document saved successfully with new path.")
            completion(nil)
        } catch {
            completion(error)
            print("Failed to copy file or save document: \(error.localizedDescription)")
        }
    }

}
