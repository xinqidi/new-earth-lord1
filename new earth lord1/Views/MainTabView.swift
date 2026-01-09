//
//  MainTabView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        // 强制访问 currentLanguage 以触发重新渲染
        let _ = languageManager.currentLanguage

        return TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Label {
                        Text(languageManager.localizedString("地图"))
                    } icon: {
                        Image(systemName: "map.fill")
                    }
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Label {
                        Text(languageManager.localizedString("领地"))
                    } icon: {
                        Image(systemName: "flag.fill")
                    }
                }
                .tag(1)

            ResourcesTabView()
                .tabItem {
                    Label {
                        Text(languageManager.localizedString("资源"))
                    } icon: {
                        Image(systemName: "cube.box.fill")
                    }
                }
                .tag(2)

            ProfileTabView()
                .tabItem {
                    Label {
                        Text(languageManager.localizedString("个人"))
                    } icon: {
                        Image(systemName: "person.fill")
                    }
                }
                .tag(3)

            MoreTabView()
                .tabItem {
                    Label {
                        Text(languageManager.localizedString("更多"))
                    } icon: {
                        Image(systemName: "ellipsis")
                    }
                }
                .tag(4)
        }
        .tint(ApocalypseTheme.primary)
        // 强制在语言变化时重新渲染
        .id(languageManager.currentLanguage)
    }
}

#Preview {
    MainTabView()
}
