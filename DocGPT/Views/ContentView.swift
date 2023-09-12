//
//  ContentView.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 4/30/23.
//


import SwiftUI
import AVKit
import MobileCoreServices
import UIKit
import PDFKit
import MSAL

struct ContentView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var vm: ContentViewModel
    @FocusState var isTextFieldFocused: Bool
    @State private var isPresentingDocumentPicker = false
    @State private var selectedFile: URL?
    @State private var isSideMenuVisible = false
    @State var authenticator: Authenticator?
    @State private var isAuthenticated = false
    @State private var account: MSALAccount? = nil
    @EnvironmentObject private var sceneDelegate: MainSceneDelegate
    @State private var accessToken: String?
    @State private var userID: String?
    @State private var givenName: String?
    @ObservedObject var pybeRequests = PybeRequests()
    @State private var selectedGroup: Group?
    @State private var navigationTitle = "Hunter"
    @State var isGroupMessage = false
    @State var shouldSendToChatGPT = true
    @State var shouldSignOutUser = false
    @State var isSignUpViewVisible = false
    @State var shouldSignInUser = false
    @State var shouldClearChatHistory = false
    @State var displayClearChatHistoryPrompt = false
    
    var body: some View {
        VStack(spacing: 0) {
            chatListView
                .navigationBarTitle(navigationTitle, displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Upload") {
                            isPresentingDocumentPicker = true
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            isSideMenuVisible = true
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .imageScale(.large)
                        }
                    }
                }
                .background(colorScheme == .light ? Color.white : Color(red: 52/255, green: 53/255, blue: 65/255, opacity: 0.5))
                .sheet(isPresented: $isPresentingDocumentPicker) {
                    DocumentPicker(filePath: $selectedFile)
                }
                .sheet(isPresented: $isSideMenuVisible) {
                    SideMenuView(userID: $userID, accessToken: $accessToken, selectedGroup: $selectedGroup, isSideMenuVisible: $isSideMenuVisible, isGroupMessage: $isGroupMessage, shouldSignOutUser: $shouldSignOutUser, shouldClearChatHistory: $shouldClearChatHistory)
                        .onDisappear {
                            if shouldSignOutUser == true {
                                authenticator?.signoutUser()
                                vm.messages = []
                                isSignUpViewVisible = true
                            } else if shouldClearChatHistory == true {
                                shouldClearChatHistory = false
                                displayClearChatHistoryPrompt = true
                            }
                            
                        }
                }
                .fullScreenCover(isPresented: $isSignUpViewVisible) {
                    SignInSignUpView(shouldSignInUser: $shouldSignInUser, isSignUpViewVisible: $isSignUpViewVisible)
                }
                .onChange(of: selectedFile) { fileURL in
                    guard let fileURL = fileURL else {
                        return
                    }
                    
                    guard fileURL.startAccessingSecurityScopedResource() else {
                        print("Error accessing security scoped resource.")
                        return
                    }
                    defer { fileURL.stopAccessingSecurityScopedResource() }
                    
                    Task {
                        let text = extractTextFromPDF(at: fileURL)
                        if let text = text {
                            await vm.uploadDocument(text: text)
                        }
                    }
                }
                .onChange(of: selectedGroup, perform: { group in
                    if let _ = selectedGroup, let group = group {
                        getChatHistoryForGroup(selectedGroup: group)
                        vm.groupID = group.id
                    }
                })
                .onChange(of: shouldSignInUser, perform: { newValue in
                    logIn()
                })
                .onChange(of: isGroupMessage, perform: { newValue in
                    if newValue == true {
                        print("DO NOTHING")
                    } else {
                        getChatHistoryForUser()
                        print("GETTING USER CHAT HISTORY")
                    }
                })
                .alert(isPresented: $displayClearChatHistoryPrompt) {
                    Alert(
                        title: Text("Are you sure you want to clear chat history?"),
                        message: Text("This action cannot be undone."),
                        primaryButton: .default(Text("Yes")) {
                            displayClearChatHistoryPrompt = false
                            clearChatHistory()
                        },
                        secondaryButton: .cancel(Text("No"))
                    )
                }

                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        logIn()
                    }
                }
        }
    }
    
    private func clearChatHistory() {
        if isGroupMessage {
            print("CLEAR CHAT HISTORY FOR GROUP")
        } else {
            if let userID = userID, let accessToken = accessToken {
                pybeRequests.clearChatHistoryForUser(userID: userID, bearerToken: accessToken) { _, error in
                    if let error = error {
                       print("HAD ERROR WHILE DELETING HISTORY \(error)")
                    } else {
                        DispatchQueue.main.async {
                            vm.messages = []
                            print("SUCCESSFULLY DELETED HISTORY")
                        }
                    }
                }
            } else {
                print("COULD NOT CLEAR CHAT HISTORY")
            }
            
        }
        
    }
    
    private func getChatHistoryForGroup(selectedGroup: Group) {
        guard let viewController = sceneDelegate.rootViewController else {
            preconditionFailure("missing root view controller")
        }
        
        let loadingVC = LoadingViewController(message: "Retrieving Chat History")
        
        DispatchQueue.main.async {
            viewController.present(loadingVC, animated: true, completion: nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let accessToken = accessToken else {
                print("Access token returned nil")
                return
            }
            pybeRequests.getChatHistoryForGroup(groupID: selectedGroup.id, bearerToken: accessToken) { response, error in
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
                        vm.messages = messages
                        loadingVC.dismiss(animated: true)
                        navigationTitle = selectedGroup.name
                    }
                }
            }
        }
    }
    
    private func getChatHistoryForUser() {
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
        
        DispatchQueue.main.async {
            viewController.present(loadingVC, animated: true, completion: nil)
        }
        
        pybeRequests.getChatHistoryForUser(userID: userID, bearerToken: accessToken) { response, error in
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
                    vm.messages = messages
                    loadingVC.dismiss(animated: true)
                    navigationTitle = "HUNTER"
                }
            }
        }
    }
    
    private func logIn() {
        DispatchQueue.main.async {
            guard let viewController = sceneDelegate.rootViewController else {
                preconditionFailure("missing root view controller")
            }
            
            authenticator = Authenticator(view: viewController)
            authenticator?.baseAuth(completionHandler: { token, userID, givenName  in
                let loadingVCChatHistory = LoadingViewController(message: "Logging In")
                DispatchQueue.main.async {
                    viewController.present(loadingVCChatHistory, animated: true)
                }
                print("token is \(String(describing: token))")
                print("userID is \(String(describing: userID))")
                
                if let token = token, let userID = userID, let givenName = givenName {
                    self.accessToken = token
                    self.userID = userID
                    self.givenName = givenName
                    vm.accessToken = token
                    vm.userID = userID
                    vm.givenName = givenName
                    
                    pybeRequests.getChatHistoryForUser(userID: userID, bearerToken: token) { response, error in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            loadingVCChatHistory.dismiss(animated: true, completion: nil)
                        }
                        
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
                                vm.messages = messages
                            }
                        }
                    }
                }
            })
        }
    }
    
    
    var chatListView: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.messages) { message in
                            MessageRowView(message: message) { message in
                                Task { @MainActor in
                                    await vm.retry(message: message)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        isTextFieldFocused = false
                    }
                }
#if os(iOS) || os(macOS)
                Divider()
                Spacer()
                if isGroupMessage {
                    HStack {
                        Toggle(isOn: $shouldSendToChatGPT) {
                            Text("chatGPT")
                        }
                        .fontWeight(.semibold)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding(.horizontal)
                        .background(colorScheme == .light ? Color.white : Color(red: 52/255, green: 53/255, blue: 65/255, opacity: 0.5))
                    }
                    Spacer()
                    Divider()
                }
                if let givenName = givenName {
                    bottomView(image: givenName, proxy: proxy)
                }
                Spacer()
#endif
            }
            .onChange(of: vm.messages) { _ in  scrollToBottom(proxy: proxy)
            }
            
            
        }
        .background(colorScheme == .light ? .white : Color(red: 52/255, green: 53/255, blue: 65/255, opacity: 0.5))
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
    
    
    func bottomView(image: String, proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let firstLetter = image.first, !image.isEmpty {
                Circle()
                    .foregroundColor(.gray)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(String(firstLetter).uppercased())
                            .foregroundColor(.white)
                            .font(.headline)
                    )
            } else {
                Image(image)
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            
            TextField("Send message", text: $vm.inputMessage, axis: .vertical)
#if os(iOS) || os(macOS)
                .textFieldStyle(.roundedBorder)
#endif
                .focused($isTextFieldFocused)
                .disabled(vm.isInteractingWithChatGPT)
            
            if vm.isInteractingWithChatGPT {
                DotLoadingView().frame(width: 60, height: 30)
            } else {
                Button {
                    Task { @MainActor in
                        isTextFieldFocused = false
                        scrollToBottom(proxy: proxy)
                        await vm.sendTapped(shouldSendToChatGPT: shouldSendToChatGPT)
                    }
                } label: {
                    Image(systemName: "paperplane.circle.fill")
                        .rotationEffect(.degrees(45))
                        .font(.system(size: 30))
                }
#if os(macOS)
                .buttonStyle(.borderless)
                .keyboardShortcut(.defaultAction)
                .foregroundColor(.accentColor)
#endif
                .disabled(vm.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let id = vm.messages.last?.id else { return }
        proxy.scrollTo(id, anchor: .bottomTrailing)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ContentView(vm: ContentViewModel(api: ChatGPTAPI(apiKey: "PROVIDE_API_KEY")))
        }
    }
}



