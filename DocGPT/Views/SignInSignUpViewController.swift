//
//  SignInSignUpViewController.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 6/22/23.
//

import SwiftUI

struct SignInSignUpView: View {
    @Binding var shouldSignInUser: Bool
    @Binding var isSignUpViewVisible: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                isSignUpViewVisible = false
                shouldSignInUser = true
            }) {
                Text("Sign In")
                .padding()
            }
        }
    }
}
