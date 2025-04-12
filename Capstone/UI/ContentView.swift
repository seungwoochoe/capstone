//
//  ContentView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-03-30.
//

import SwiftUI
import SwiftData

// MARK: - Main Content View

struct ContentView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ScannedRoom.processedDate, order: .reverse) var scannedRooms: [ScannedRoom]

    @State private var searchText: String = ""
    @State private var showScanner: Bool = false
    @State private var showAbout: Bool = false
    @State private var selectedRoom: ScannedRoom? = nil

    var filteredRooms: [ScannedRoom] {
        if searchText.isEmpty {
            return scannedRooms
        } else {
            return scannedRooms.filter {
                $0.roomName.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List(filteredRooms, id: \.roomID) { room in
                    Button {
                        selectedRoom = room
                    } label: {
                        RoomRowView(room: room)
                    }
                }
                .navigationTitle("3D Room Scanner")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            Menu {
                                Button("About") {
                                    showAbout = true
                                }
                                Button("Log Out") {
                                    logOutUser()
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                
                BottomGradientBlur()
                    .frame(height: 90)
                    .overlay(
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.largeTitle)
                                .foregroundColor(colorScheme == .light ? .accentColor : .white)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(colorScheme == .light ? Color(.systemBackground) : .accentColor))
                                .shadow(color: colorScheme == .light ? .secondary.opacity(0.3) : .black.opacity(0.3), radius: 15)
                        }
                    )
            }
            .searchable(text: $searchText)
            .overlay {
                if filteredRooms.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView {
                            Text("Start Scanning")
                                .fontWeight(.semibold)
                        } description: {
                            Text("Tap the plus button to get started.")
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .navigationDestination(item: $selectedRoom) { room in
                Room3DViewer(scannedRoom: room)
            }
            .fullScreenCover(isPresented: $showScanner) {
                RoomScannerView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func logOutUser() {
        
    }
}

// MARK: - Room Row View

struct RoomRowView: View {
    let room: ScannedRoom
    
    var body: some View {
        HStack {
            // Placeholder thumbnail
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            VStack(alignment: .leading) {
                Text(room.roomName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Completed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Bottom Gradient Blur View

struct BottomGradientBlur: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.clear, Color(.systemBackground)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview(traits: .sampleData) {
    ContentView()
}
