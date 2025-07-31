//
//  ContentView.swift
//  SwiftUI_PermissionExample
//
//  Created by cano on 2025/07/30.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Usage") {
                    Text(".permissionSheet([.camera...])")
                        .monospaced()
                }
            }
            .navigationTitle("Permission Example")
        }
        .permissionSheet([.location, .camera, .microphone, .photoLibrary])
    }
}

#Preview {
    ContentView()
}
