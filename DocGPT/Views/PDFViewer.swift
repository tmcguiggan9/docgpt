//
//  PDFViewer.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 2/26/24.
//

import SwiftUI
import PDFKit

struct PDFViewer: View {
    let pdfURL: URL

    var body: some View {
        PDFKitRepresentedView(pdfURL)
            .edgesIgnoringSafeArea(.all)
    }
}

struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    init(_ url: URL) {
        self.url = url
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        print("Trying to read in makeUIView with url \(url)") // For debugging
        if let document = PDFDocument(url: url) {
            print("document is \(document)")
            pdfView.document = document
        } else {
            print("Could not load the PDF document.")
        }
        
        pdfView.autoScales = true
        return pdfView
    }


    func updateUIView(_ uiView: PDFView, context: Context) {
        // empty for now
    }
}

