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
    @Query(sort: \Scan.processedDate, order: .reverse) var scans: [Scan]
    @Query(sort: \UploadTask.createdAt, order: .reverse) var uploadTasks: [UploadTask]

    @State private var searchIsPresented: Bool = false
    @State private var searchText: String = ""
    @State private var showScanner: Bool = false
    @State private var showAbout: Bool = false
    @State private var selected: Scan? = nil

    var filteredScans: [Scan] {
        if searchText.isEmpty {
            return scans
        } else {
            return scans.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(uploadTasks, id: \.id) { uploadTask in
                        UploadTaskRowView(uploadTask: uploadTask)
                    }
                    
                    ForEach(filteredScans, id: \.id) { scan in
                        Button {
                            selected = scan
                        } label: {
                            ScanRowView(scan: scan)
                        }
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
                    .overlay {
                        if !searchIsPresented {
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
                        }
                    }
            }
            .searchable(text: $searchText, isPresented: $searchIsPresented)
            .overlay {
                if uploadTasks.isEmpty && filteredScans.isEmpty {
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
            .navigationDestination(item: $selected) { scan in
                Model3DViewer(scan: scan)
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

// MARK: - UploadTask Row View

struct UploadTaskRowView: View {
    let uploadTask: UploadTask
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            VStack(alignment: .leading) {
                Text(uploadTask.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(uploadTask.uploadStatus.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Room Row View

struct ScanRowView: View {
    let scan: Scan
    
    var body: some View {
        HStack {
            // Placeholder thumbnail
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            VStack(alignment: .leading) {
                Text(scan.name)
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

#Preview(traits: .uploadTaskSampleData) {
    ContentView()
}
