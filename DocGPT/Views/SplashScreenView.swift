//
//  SplashScreenView.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 10/27/23.
//

import SwiftUI

struct SplashScreenView: View {
    
    @State private var isActive = false
    @StateObject var contentViewModel = ContentViewModel(api: ChatGPTAPI(apiKey: "YOUR API KEY"))
    @StateObject var documentsViewModel = DocumentsViewModel()
    @EnvironmentObject private var sceneDelegate: MainSceneDelegate
    
    var body: some View {
        if isActive == true {
            MainView(contentViewModel: contentViewModel, documentsViewModel: documentsViewModel)
        } else {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                VStack {
                    VStack {
                        Image("appstore")
                            .resizable()
                            .aspectRatio(contentMode: .fit) //
                            .frame(width: 120, height: 120)
                        Text("HUNTER")
                            .font(Font.custom("Baskerville-Bold", size: 26))
                            .foregroundColor(.black)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        contentViewModel.logIn(isFreshOpen: true, sceneDelegate: sceneDelegate) {
                            self.isActive = true
                        }
                    }
                }
            }
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
            .previewLayout(.fixed(width: 320, height: 568))
    }
}
