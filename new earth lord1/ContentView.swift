//
//  ContentView.swift
//  new earth lord1
//
//  Created by 新起点 on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            Text("Developed by nanjifangke")
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
