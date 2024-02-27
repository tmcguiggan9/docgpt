//
//  View+TypeErasure.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 11/7/23.
//

import SwiftUI

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}
