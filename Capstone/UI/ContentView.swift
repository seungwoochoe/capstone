//
//  ContentView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-03-30.
//

import SwiftUI
import Combine
import OSLog

// MARK: - Main Content View

struct ContentView: View {
    
    @Environment(\.injected) private var injected
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    
    @State private var scans: [Scan] = []
    @State private var uploadTasks: [UploadTask] = []

    @State private var searchIsPresented: Bool = false
    @State private var searchText: String = ""
    @State private var showingScanner: Bool = false
    @State private var showingSettings: Bool = false
    @State private var selected: Scan? = nil
    @State private var showingCameraAccessDeniedAlert: Bool = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
    var filteredUploadTasks: [UploadTask] {
        if searchText.isEmpty {
            return uploadTasks
        } else {
            return uploadTasks.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
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
        content
            .onAppear {
                loadUploadTasks()
                loadScans()
            }
            .onReceive(routingUpdate) { newValue in
                if let scan = scans.first(where: { $0.id == newValue.selectedScanID }) {
                    selected = scan
                }
            }
    }
    
    var content: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if !searchIsPresented && filteredUploadTasks.isEmpty && filteredScans.isEmpty {
                        ScrollView {
                            ContentUnavailableView {
                                Label("Start Scanning", systemImage: "camera")
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
                                ForEach(filteredUploadTasks) { uploadTask in
                                    UploadTaskRowView(uploadTask: uploadTask)
                                }
                                .onDelete(perform: deleteUploadTasks)
                            } header: {
                                if !filteredUploadTasks.isEmpty {
                                    Text("Pending")
                                }
                            }
                            
                            Section {
                                ForEach(filteredScans) { scan in
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
                .navigationBarTitleDisplayMode(.automatic)
                .toolbar {
                    ToolbarItem {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
                
                BottomGradientBlur()
                    .frame(height: 90)
                    .overlay {
                        if !searchIsPresented {
                            Button {
                                Task {
                                    do {
                                        try await injected.interactors.userPermissions.request(permission: .pushNotifications)
                                        if injected.appState[\.permissions.camera] == .granted {
                                            showingScanner = true
                                        } else {
                                            showingCameraAccessDeniedAlert = true
                                        }
                                    } catch {
                                        logger.error("Failed to request notification permission: \(error)")
                                    }
                                }
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
            .alert("Camera Access Denied", isPresented: $showingCameraAccessDeniedAlert) {
                Button("Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable Camera access in Settings to scan your room.")
            }
            .overlay {
                if searchIsPresented && filteredUploadTasks.isEmpty && filteredScans.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationDestination(item: $selected) { scan in
                Model3DViewer(scan: scan)
            }
            .fullScreenCover(isPresented: $showingScanner) {
                loadUploadTasks()
            } content: {
                RoomScannerView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(showingSettings: $showingSettings)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var routingUpdate: AnyPublisher<AppState.ViewRouting, Never> {
        injected.appState.updates(for: \.routing)
    }
    
    private func loadUploadTasks() {
        Task.detached {
            let uploadTasks = try await injected.interactors.scanInteractor.fetchUploadTasks()
            
            await MainActor.run {
                withAnimation {
                    self.uploadTasks = uploadTasks
                }
            }
        }
    }
    
    private func loadScans() {
        Task.detached {
            let scans = try await injected.interactors.scanInteractor.fetchScans()
            
            await MainActor.run {
                withAnimation {
                    self.scans = scans
                }
            }
        }
    }
    
    private func deleteUploadTasks(offsets: IndexSet) {
        for index in offsets {
            let uploadTask = filteredUploadTasks[index]
            
            Task {
                try await injected.interactors.scanInteractor.delete(uploadTask)
            }
        }
        
        loadUploadTasks()
    }
    
    private func deleteScan(offsets: IndexSet) {
        for index in offsets {
            let scan = filteredScans[index]
            
            Task {
                try await injected.interactors.scanInteractor.delete(scan)
            }
        }
        
        loadScans()
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
                Text(uploadTask.uploadStatus.displayString)
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
        HStack(spacing: 18) {
            USDZThumbnailView(
                url: scan.usdzURL,
                size: CGSize(width: 50, height: 50)
            )
            Text(scan.name)
                .font(.headline)
                .foregroundColor(.primary)
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

#Preview {
    ContentView()
}
