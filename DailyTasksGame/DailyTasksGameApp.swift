//
//  DailyTasksGameApp.swift
//  DailyTasksGame
//
//  Created by cmStudent on 2026/11/16.
//

import SwiftUI
import SwiftData

@main
struct DailyTasksGameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Game.self, TaskItem.self, CompletionRecord.self])
    }
}
