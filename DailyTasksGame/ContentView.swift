//
//  ContentView.swift
//  DailyTasksGame
//
//  Created by cmStudent on 2026/11/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "list.bullet")
                }

            StatisticsView()
                .tabItem {
                    Label("統計", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
