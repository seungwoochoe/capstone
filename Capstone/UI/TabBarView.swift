//
//  TabBarView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI

struct TabBarView: View {
    var body: some View {
        TabView {
            ScanRoomView()
                .tabItem {
                    Label("Scan Room", systemImage: "camera")
                }
            ScannedRoomsView()
                .tabItem {
                    Label("Scanned Rooms", systemImage: "list.bullet")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
