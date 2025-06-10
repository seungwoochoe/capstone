//
//  ContentView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-03-30.
//

import SwiftUI
import Combine
import OSLog

enum SortField: Int, CaseIterable, Defaults.Serializable {
    case createdAt
    case title
    
    var label: String {
        switch self {
        case .createdAt: return "Date Created"
        case .title:     return "Title"
        }
    }
}

enum SortOrder: Int, CaseIterable, Defaults.Serializable {
    case ascending
    case descending
    
    var label: String {
        switch self {
        case .ascending:  return "Ascending"
        case .descending: return "Descending"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    
    @Environment(\.injected) private var injected
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    
    @State private var sortField: SortField = .createdAt
    @State private var sortOrder: SortOrder = .ascending
    
    @State private var scans: [Scan] = []
    @State private var uploadTasks: [UploadTask] = []
    
    @State private var searchIsPresented: Bool = false
    @State private var searchText: String = ""
    @State private var showingScanner: Bool = false
    @State private var showingSettings: Bool = false
    @State private var selected: Scan? = nil
    @State private var showingCameraAccessDeniedAlert: Bool = false
    
    private let logger = Logger.forType(ContentView.self)
    
    // Filter + Sort Logic
    
    private var filteredAndSortedUploadTasks: [UploadTask] {
        let base = searchText.isEmpty
        ? uploadTasks
        : uploadTasks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted { a, b in
            switch sortField {
            case .title:
                let result = a.name.localizedCaseInsensitiveCompare(b.name)
                if sortOrder == .ascending {
                    return result == .orderedAscending
                } else {
                    return result == .orderedDescending
                }
            case .createdAt:
                return sortOrder == .ascending
                ? a.createdAt < b.createdAt
                : a.createdAt > b.createdAt
            }
        }
    }
    
    private var filteredAndSortedScans: [Scan] {
        let base = searchText.isEmpty
        ? scans
        : scans.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted { a, b in
            switch sortField {
            case .title:
                let result = a.name.localizedCaseInsensitiveCompare(b.name)
                if sortOrder == .ascending {
                    return result == .orderedAscending
                } else {
                    return result == .orderedDescending
                }
            case .createdAt:
                return sortOrder == .ascending
                ? a.createdAt < b.createdAt
                : a.createdAt > b.createdAt
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        content
            .onAppear {
                Task.detached {
                    try await injected.interactors.scanInteractor.fetchUploadTasks()
                    try await injected.interactors.scanInteractor.fetchScans()
                }
            }
            .onReceive(injected.appState.updates(for: \.sortField)) {
                sortField = $0
            }
            .onReceive(injected.appState.updates(for: \.sortOrder)) {
                sortOrder = $0
            }
            .onReceive(injected.appState.updates(for: \.uploadTasks)) {
                uploadTasks = $0
            }
            .onReceive(injected.appState.updates(for: \.scans)) {
                scans = $0
            }
            .onReceive(injected.appState.updates(for: \.routing)) { newValue in
                if let scan = scans.first(where: { $0.id == newValue.selectedScanID }) {
                    selected = scan
                }
            }
    }
    
    var content: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                Group {
                    if !searchIsPresented
                        && filteredAndSortedUploadTasks.isEmpty
                        && filteredAndSortedScans.isEmpty {
                        
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
                        
                    } else {
                        List {
                            Section {
                                ForEach(filteredAndSortedUploadTasks) { task in
                                    UploadTaskRowView(uploadTask: task)
                                }
                                .onDelete(perform: deleteUploadTasks)
                            } header: {
                                if !filteredAndSortedUploadTasks.isEmpty {
                                    Text("Pending")
                                }
                            }
                            
                            Section {
                                ForEach(filteredAndSortedScans) { scan in
                                    Button {
                                        selected = scan
                                    } label: {
                                        ScanRowView(scan: scan)
                                    }
                                }
                                .onDelete(perform: deleteScan)
                            } header: {
                                if !filteredAndSortedScans.isEmpty {
                                    Text("Completed")
                                }
                            }
                        }
                    }
                }
                .animation(.default, value: filteredAndSortedUploadTasks)
                .animation(.default, value: filteredAndSortedScans)
                .navigationTitle("3D Room Scanner")
                .navigationBarTitleDisplayMode(.automatic)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        
                        Menu {
                            Picker("Sort Field", selection: Binding<SortField>(
                                get: { sortField },
                                set: { newField in
                                    Task {
                                        await injected.interactors.scanInteractor.updateSortField(newField)
                                    }
                                }
                            )) {
                                ForEach(SortField.allCases, id: \.self) { field in
                                    Text(field.label).tag(field)
                                }
                            }
                            
                            Divider()
                            
                            Picker("Sort Order", selection: Binding<SortOrder>(
                                get: { sortOrder },
                                set: { newOrder in
                                    Task {
                                        await injected.interactors.scanInteractor.updateSortOrder(newOrder)
                                    }
                                }
                            )) {
                                ForEach(SortOrder.allCases, id: \.self) { order in
                                    Text(order.label).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
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
                                        try await injected.interactors.userPermissions.request(permission: .camera)
                                        if injected.appState[\.permissions.camera] == .granted {
                                            showingScanner = true
                                        } else {
                                            showingCameraAccessDeniedAlert = true
                                        }
                                        
                                        try await injected.interactors.userPermissions.request(permission: .pushNotifications)
                                    } catch {
                                        logger.error("Camera permission failed: \(error)")
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
                if searchIsPresented
                    && filteredAndSortedUploadTasks.isEmpty
                    && filteredAndSortedScans.isEmpty {
                    
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationDestination(item: $selected) { scan in
                Model3DViewer(scan: scan)
                    .onDisappear {
                        injected.appState[\.routing.selectedScanID] = nil
                    }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                RoomScannerView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(showingSettings: $showingSettings)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func deleteUploadTasks(offsets: IndexSet) {
        for idx in offsets {
            let task = filteredAndSortedUploadTasks[idx]
            Task.detached {
                try await injected.interactors.scanInteractor.delete(task)
            }
        }
    }
    
    private func deleteScan(offsets: IndexSet) {
        for idx in offsets {
            let scan = filteredAndSortedScans[idx]
            Task.detached {
                try await injected.interactors.scanInteractor.delete(scan)
            }
        }
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
    
    @Environment(\.injected) private var injected
    
    let scan: Scan
    
    var body: some View {
        HStack(spacing: 18) {
            ThumbnailView(
                url: scan.modelURL(fileManager: injected.services.fileManager),
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
