//
//  DocumentsViewModel.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 2/26/24.
//

import Foundation
import CoreData

class DocumentsViewModel: ObservableObject {
    @Published var documents: [Document] = []
    
    private var context = PersistenceController.shared.container.viewContext
    
    func fetchDocuments() {
        DispatchQueue.main.async {
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            
            do {
                self.documents = try self.context.fetch(fetchRequest)
            } catch {
                print("Failed to fetch documents: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteDocument(at offsets: IndexSet) {
            for index in offsets {
                let document = documents[index]
                context.delete(document)
            }
            
            do {
                try context.save()
                documents.remove(atOffsets: offsets)
            } catch {
                print("Failed to delete document: \(error.localizedDescription)")
            }
        }

}

