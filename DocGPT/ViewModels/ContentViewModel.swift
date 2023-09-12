//
//  ContentViewModel.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 4/30/23.
//

import Foundation
import SwiftUI
import AVKit

class ContentViewModel: ObservableObject {
    
    @Published var isInteractingWithChatGPT = false
    @Published var messages: [MessageRow] = []
    @Published var inputMessage: String = ""
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
    
    @MainActor
    func uploadDocument(text: String) async {
        let text = "Can you summarize the following document? \n" + text
        await send(text: "Uploading Document...", documentText: text)
    }
    
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
    
}
