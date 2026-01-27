//
//  MainTabView.swift
//  new earth lord1
//
//  Created by nanjifangke on 2025/12/24.
//

import SwiftUI

// MARK: - Tab 枚举

enum MainTab: Int, CaseIterable {
    case map = 0
    case territory = 1
    case resources = 2
    case communication = 3
    case profile = 4
    case more = 5

    var title: String {
        switch self {
        case .map: return "地图"
        case .territory: return "领地"
        case .resources: return "资源"
        case .communication: return "通讯"
        case .profile: return "个人"
        case .more: return "更多"
        }
    }

    var icon: String {
        switch self {
        case .map: return "map.fill"
        case .territory: return "flag.fill"
        case .resources: return "cube.box.fill"
        case .communication: return "antenna.radiowaves.left.and.right"
        case .profile: return "person.fill"
        case .more: return "ellipsis"
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @State private var selectedTab: MainTab = .map
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        // 强制访问 currentLanguage 以触发重新渲染
        let _ = languageManager.currentLanguage

        return VStack(spacing: 0) {
            // 内容区域
            Group {
                switch selectedTab {
                case .map:
                    MapTabView()
                case .territory:
                    TerritoryTabView()
                case .resources:
                    ResourcesTabView()
                case .communication:
                    CommunicationTabView()
                case .profile:
                    ProfileTabView()
                case .more:
                    MoreTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 自定义底部导航栏
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        // 强制在语言变化时重新渲染
        .id(languageManager.currentLanguage)
    }
}

// MARK: - 自定义底部导航栏

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    TabBarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(ApocalypseTheme.cardBackground)
    }
}

// MARK: - 单个 Tab 按钮

struct TabBarButton: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .frame(height: 24)

                Text(languageManager.localizedString(tab.title))
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}
