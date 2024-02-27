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
import MSAL

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var vm: ContentViewModel
    @ObservedObject var documentsViewModel: DocumentsViewModel
    @FocusState var isTextFieldFocused: Bool
    @State private var isPresentingDocumentPicker = false
    @State private var selectedFile: URL?
    @State private var isSideMenuVisible = false
    @State private var isAuthenticated = false
    @State private var account: MSALAccount? = nil
    @State private var selectedGroup: Group?
    @EnvironmentObject private var sceneDelegate: MainSceneDelegate
    @State var isGroupMessage = false
    @State var shouldSendToChatGPT = true
    @State var shouldSignOutUser = false
    @State var isSignUpViewVisible = false
    @State var shouldSignInUser = false
    @State var shouldClearChatHistory = false
    @State var displayClearChatHistoryPrompt = false
    
    var body: some View {
        NavigationView{
            VStack(spacing: 0) {
                chatListView
                    .navigationBarTitle(vm.navigationTitle, displayMode: .inline)
                    .navigationBarItems(
                        leading: Button("Upload") {
                            isPresentingDocumentPicker = true
                        },
                        trailing: Button(action: {
                            isSideMenuVisible = true
                        }) {
                            Image(systemName: "line.horizontal.3").imageScale(.large)
                        }
                    )
                    .background(colorScheme == .light ? Color.white : Color(red: 52/255, green: 53/255, blue: 65/255, opacity: 0.5))
                    .sheet(isPresented: $isPresentingDocumentPicker) {
                        DocumentPicker(filePath: $selectedFile)
                    }
                    .sheet(isPresented: $isSideMenuVisible) {
                        SideMenuView(userID: $vm.userID, accessToken: $vm.accessToken, selectedGroup: $selectedGroup, isSideMenuVisible: $isSideMenuVisible, isGroupMessage: $isGroupMessage, shouldSignOutUser: $shouldSignOutUser, shouldClearChatHistory: $shouldClearChatHistory)
                            .onDisappear {
                                if shouldSignOutUser == true {
                                    vm.authenticator?.signoutUser()
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
                            let text = vm.extractTextFromPDF(at: fileURL)
                            if let text = text {
                                await vm.uploadDocument(text: text)
                                vm.uploadPDF(pdfURL: fileURL) {
                                    documentsViewModel.fetchDocuments()
                                }
                           }
                        }
                    }
                    .onChange(of: selectedGroup, perform: { group in
                        if let _ = selectedGroup, let group = group {
                            vm.getChatHistoryForGroup(selectedGroup: group, sceneDelegate: sceneDelegate)
                            vm.groupID = group.id
                        }
                    })
                    .onChange(of: shouldSignInUser, perform: { newValue in
                        vm.logIn(isFreshOpen: false, sceneDelegate: sceneDelegate) {
                            print("FreshOpen is false")
                        }
                    })
                    .onChange(of: isGroupMessage, perform: { newValue in
                        if newValue == true {
                            print("DO NOTHING")
                        } else {
                            vm.getChatHistoryForUser(isFreshOpen: false, sceneDelegate: sceneDelegate) {
                                print("isFreshOpen is false")
                            }
                            print("GETTING USER CHAT HISTORY")
                        }
                    })
                    .alert(isPresented: $displayClearChatHistoryPrompt) {
                        Alert(
                            title: Text("Are you sure you want to clear chat history?"),
                            message: Text("This action cannot be undone."),
                            primaryButton: .default(Text("Yes")) {
                                displayClearChatHistoryPrompt = false
                                vm.clearChatHistory(isGroupMessage: isGroupMessage)
                            },
                            secondaryButton: .cancel(Text("No"))
                        )
                    }
            }
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
                if let givenName = vm.givenName {
                    bottomView(image: givenName, proxy: proxy)
                }
                Spacer()
#endif
            }
            .onChange(of: vm.messages) { _ in  scrollToBottom(proxy: proxy)
            }
            .onAppear() {
                scrollToBottom(proxy: proxy)
            }
            
            
        }
        .background(colorScheme == .light ? .white : Color(red: 52/255, green: 53/255, blue: 65/255, opacity: 0.5))
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
            ContentView(vm: ContentViewModel(api: ChatGPTAPI(apiKey: "PROVIDE_API_KEY")), documentsViewModel: DocumentsViewModel())
        }
    }
}



