//
//  MainView.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 2/26/24.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var contentViewModel: ContentViewModel
    @ObservedObject var documentsViewModel: DocumentsViewModel
    var body: some View {
        TabView {
            NavigationStack {
                ContentView(vm: contentViewModel, documentsViewModel: documentsViewModel)
            }
            .tabItem {
                Label("Chat", systemImage: "message")
            }
            NavigationStack {
                DocumentsView(vm: documentsViewModel)
            }
            .tabItem {
                Label("Documents", systemImage: "doc")
            }
        }
    }
}



// Assuming ContentView is defined as you provided
// struct ContentView: View { ... }

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        // Assuming ContentViewModel can be initialized with a dummy or mock ChatGPTAPI
        MainView(contentViewModel: ContentViewModel(api: ChatGPTAPI(apiKey: "1234")), documentsViewModel: DocumentsViewModel())
    }
}
