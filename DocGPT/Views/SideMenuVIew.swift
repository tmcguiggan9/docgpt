//
//  SideMenuVIew.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 4/30/23.
//

import SwiftUI

struct SideMenuView: View {
    @State private var groups: [Group]? = nil
    @ObservedObject var pybeRequests = PybeRequests()
    @Binding var userID: String?
    @Binding var accessToken: String?
    @Binding var selectedGroup: Group?
    @Binding var isSideMenuVisible: Bool
    @Binding var isGroupMessage: Bool
    @Binding var shouldSignOutUser: Bool
    @Binding var shouldClearChatHistory: Bool
    
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Groups")
                .bold()
                .padding()
            
            List {
                ForEach(groups ?? [], id: \.self) { group in
                    Text(group.name)
                        .foregroundColor(selectedGroup == group ? .blue : .primary)
                                .onTapGesture {
                                    selectedGroup = group // Set the selected group to the tapped group
                                    isGroupMessage = true
                                    isSideMenuVisible = false
                                }
                }
            }
            if isGroupMessage == true {
                Button(action: {
                    isSideMenuVisible = false
                    isGroupMessage = false
                }) {
                    Text("Return to Personal Chat")
                    .padding()
                }
            }
            if isGroupMessage == false {
                Button(action: {
                    isSideMenuVisible = false
                    shouldClearChatHistory = true
                }) {
                    Text("Clear Chat History")
                    .padding()
                }
            }
            Button(action: {
                isSideMenuVisible = false
                shouldSignOutUser = true
            }) {
                Text("Sign Out")
                .padding()
            }
        }
        .onAppear(perform: {
            
            if let userID = userID, let accessToken = accessToken {
                pybeRequests.retrieveGroupsForUser(userID: userID, bearerToken: accessToken) { groups, error in
                    if let error = error {
                        print("Error: \(error)")
                    } else if let groups = groups {
                        self.groups = groups
                    }
                }
            }
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Add this to make the side menu fill the available space
        .background(Color(UIColor.systemBackground)) // Set the solid background color here and ignore safe area edges
    }
    
}

struct Groups: Decodable {
    var groups: [Group]
}

struct Group: Decodable, Hashable {
    var id: String
    var name: String
}

struct SideMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SideMenuView(userID: .constant("user123"), accessToken: .constant("abc123"), selectedGroup: .constant(nil), isSideMenuVisible: .constant(false), isGroupMessage: .constant(false), shouldSignOutUser: .constant(false), shouldClearChatHistory: .constant(false))
    }
}

