//
//  ContentView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-03-30.
//

import SwiftUI
import RealityKit
import SwiftData

// MARK: - Main Content View

struct ContentView: View {
    @Query(sort: \ScannedRoom.processedDate, order: .reverse) var scannedRooms: [ScannedRoom]

    @State private var showSearch: Bool = false
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
                // Use a List; you might also use a LazyVGrid if you prefer grid layout
                List(filteredRooms, id: \.roomID) { room in
                    Button {
                        selectedRoom = room
                    } label: {
                        RoomRowView(room: room)
                    }
                }
                .navigationTitle("Scanned Rooms")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            // Toggle the search overlay
                            Button {
                                withAnimation { showSearch.toggle() }
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            
                            // Menu button with additional options
                            Menu {
                                Button("Log Out") {
                                    logOutUser()
                                }
                                Button("About") {
                                    showAbout = true
                                }
                                // You could add a "Settings" option here if needed.
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                // Search overlay view
                if showSearch {
                    VStack {
                        HStack {
                            TextField("Search Rooms", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                            Button("Cancel") {
                                withAnimation {
                                    showSearch = false
                                    searchText = ""
                                }
                            }
                        }
                        .padding()
                        Spacer()
                    }
                    // Using ultra-thin material to mimic a blur effect
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .top))
                }
                
                // Bottom area with gradient blur and floating "+" button
                VStack(spacing: 0) {
                    BottomGradientBlur()
                        .frame(height: 100)
                        // Place the "+" button on top of the blurred background
                        .overlay(
                            Button(action: {
                                // Start the scanning flow
                                showScanner = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Circle().fill(Color.blue))
                            }
                            .padding(.bottom, 20)
                        )
                }
            }
            // Present the scanning flow, about view, and 3D viewer as modal sheets:
            .sheet(isPresented: $showScanner) {
                RoomScannerView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(item: $selectedRoom) { room in
                Room3DViewer(scannedRoom: room)
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
            // Placeholder thumbnail (replace with an actual image if available)
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            VStack(alignment: .leading) {
                Text(room.roomName)
                    .font(.headline)
                Text(statusText(for: room))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // Determine upload/processing status.
    private func statusText(for room: ScannedRoom) -> String {
        // Replace with logic that tracks processing: “Uploading…”, “Processing…”, “Completed”
        return "Completed"
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
        .blur(radius: 10)
    }
}

// MARK: - Room Scanner View

struct RoomScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var roomName: String = ""
    // Include additional state variables for camera permissions, ARKit capture, image sampling, etc.
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Scanning Tips")
                    .font(.title2)
                Text("Ensure good lighting and move slowly for best results.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Button to start ARKit scanning (integration with ARKit/RealityKit needed)
                Button("Start Scan") {
                    // Initiate ARKit scanning session.
                    // Sample 50 images, then prompt the user to name the room,
                    // upload images and then delete temporary data upon success.
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                // Room name input field (if you want to ask for a room name prior or after scanning)
                TextField("Enter Room Name", text: $roomName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Scan Room")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 3D Model Viewer

struct Room3DViewer: View {
    let scannedRoom: ScannedRoom
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // ARViewContainer displays the 3D model using RealityKit
                ARViewContainer(usdzURL: scannedRoom.usdzURL)
                    .ignoresSafeArea()
                
                // Overlay controls for export and deletion
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        Button {
                            exportModel()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .padding()
                                .background(Capsule().fill(Color.blue.opacity(0.8)))
                                .foregroundColor(.white)
                        }
                        
                        Button {
                            deleteRoom(scannedRoom)
                            dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .padding()
                                .background(Capsule().fill(Color.red.opacity(0.8)))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(scannedRoom.roomName)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Export and Delete Handlers
    
    private func exportModel() {
        // Use UIActivityViewController to share the USDZ file.
        // (Implement the actual export logic based on your needs.)
    }
    
    private func deleteRoom(_ room: ScannedRoom) {
        // Delete the room from local storage.
        // (Integrate SwiftData deletion here.)
    }
}

// MARK: - ARView Container

struct ARViewContainer: UIViewRepresentable {
    let usdzURL: URL

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        // Attempt to load the USDZ model and add it to the scene.
        do {
            let modelEntity = try ModelEntity.load(contentsOf: usdzURL)
            let anchorEntity = AnchorEntity(world: .zero)
            anchorEntity.addChild(modelEntity)
            arView.scene.addAnchor(anchorEntity)
        } catch {
            print("Error loading model: \(error)")
        }
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update the AR view if needed.
    }
}

// MARK: - Preview

#Preview(traits: .sampleData) {
    ContentView()
}
