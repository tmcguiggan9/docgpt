//
//  DocumentsView.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 2/26/24.
//

import SwiftUI

struct DocumentsView: View {
    @ObservedObject var vm: DocumentsViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(vm.documents, id: \.self) { document in
                    if let filePath = document.filePath {
                        let url = URL(fileURLWithPath: filePath)
                        NavigationLink(destination: PDFViewer(pdfURL: url)) {
                            Text(document.name ?? "Unnamed Document")
                        }
                    } else {
                        Text(document.name ?? "Unnamed Document")
                    }
                }
                .onDelete(perform: vm.deleteDocument)
            }
            .navigationTitle("Documents")
            .onAppear {
                vm.fetchDocuments()
            }
        }
    }
}




struct DocumentsView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentsView(vm: DocumentsViewModel())
    }
}
