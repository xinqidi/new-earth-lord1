//
//  TestView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/23.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            // 淡蓝色背景
            Color(red: 0.7, green: 0.85, blue: 1.0)
                .ignoresSafeArea()

            // 大标题
            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
        }
    }
}

#Preview {
    TestView()
}
