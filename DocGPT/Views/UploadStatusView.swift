//
//  UploadStatusView.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 2/26/24.
//

import SwiftUI

struct UploadStatusView: View {
    var uploadStatus: UploadStatus
    
    @State private var viewOpacity = 1.0

    var body: some View {
        VStack {
            switch uploadStatus {
            case .none:
                EmptyView()
            case .uploading:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
            case .success:
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("Document Uploaded")
                        .font(.body)
                        .foregroundColor(.green)
                }
            case .failure(let errorMessage):
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(10)
        .frame(width: 300, height: 200, alignment: .center)
        .opacity(viewOpacity)
        .onChange(of: uploadStatus) { newStatus in
            if newStatus != .none {
                viewOpacity = 1
                if newStatus != .uploading {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 1)) {
                            self.viewOpacity = 0
                        }
                    }
                }
            }
        }
    }
}





enum UploadStatus: Equatable {
    case none
    case uploading
    case success
    case failure(String) // Contains an error message
}

