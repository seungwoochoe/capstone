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
    
    @Environment(\.injected) private var injected
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \DBModel.Scan.processedDate, order: .reverse) var scans: [DBModel.Scan]
    @Query(sort: \DBModel.UploadTask.createdAt, order: .reverse) var uploadTasks: [DBModel.UploadTask]

    @State private var searchIsPresented: Bool = false
    @State private var searchText: String = ""
    @State private var showScanner: Bool = false
    @State private var showAbout: Bool = false
    @State private var selected: DBModel.Scan? = nil
    
    var filteredUploadTasks: [DBModel.UploadTask] {
        if searchText.isEmpty {
            return uploadTasks
        } else {
            return uploadTasks.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var filteredScans: [DBModel.Scan] {
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
                Group {
                    if !searchIsPresented && filteredUploadTasks.isEmpty && filteredScans.isEmpty {
                        ScrollView {
                            ContentUnavailableView {
                                Text("Start Scanning")
                                    .fontWeight(.semibold)
                            } description: {
                                Text("Tap the plus button to get started.")
                            }
                        }
                        .padding(.bottom, 40)
                        .defaultScrollAnchor(.center, for: .alignment)
                    }
                    else {
                        List {
                            Section {
                                ForEach(filteredUploadTasks, id: \.id) { uploadTask in
                                    UploadTaskRowView(uploadTask: uploadTask)
                                }
                                .onDelete(perform: deleteUploadTasks)
                            } header: {
                                if !filteredUploadTasks.isEmpty {
                                    Text("Pending")
                                }
                            }
                            
                            Section {
                                ForEach(filteredScans, id: \.id) { scan in
                                    Button {
                                        selected = scan
                                    } label: {
                                        ScanRowView(scan: scan)
                                    }
                                }
                                .onDelete(perform: deleteScan)
                            } header: {
                                if !filteredScans.isEmpty {
                                    Text("Completed")
                                }
                            }
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
                if searchIsPresented && filteredUploadTasks.isEmpty && filteredScans.isEmpty {
                    ContentUnavailableView.search(text: searchText)
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
    
    private func deleteUploadTasks(offsets: IndexSet) {
        for index in offsets {
            let uploadTask = filteredUploadTasks[index]
            
            Task {
                try await injected.interactors.scanInteractor.delete(uploadTask: uploadTask)
            }
        }
    }
    
    private func deleteScan(offsets: IndexSet) {
        for index in offsets {
            let scan = filteredScans[index]
            
            Task {
                try await injected.interactors.scanInteractor.delete(scan: scan)
            }
        }
    }
    
    private func logOutUser() {
        
    }
}

// MARK: - UploadTask Row View

struct UploadTaskRowView: View {
    let uploadTask: DBModel.UploadTask
    
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
    let scan: DBModel.Scan
    
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

#Preview(traits: .sampleData) {
    ContentView()
}
