//
//  MessageRow.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 4/30/23.
//

import SwiftUI

struct MessageRow: Identifiable, Equatable {
    let id = UUID()
    var isInteractingWithChatGPT: Bool
    
    let sendImage: String
    let sendText: String
    
    let responseImage: String
    var responseText: String?
    
    var responseError: String?
}
