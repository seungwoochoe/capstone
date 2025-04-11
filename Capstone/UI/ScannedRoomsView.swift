//
//  ScannedRoomsView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI

struct ScannedRoomsView: View {
    // This view lists the scanned rooms along with their status.
    @State private var rooms: [ScannedRoom] = []
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationView {
            List(filteredRooms(), id: \.objectID) { room in
                NavigationLink(destination: RoomDetailView(room: room)) {
                    VStack(alignment: .leading) {
                        Text(room.roomName)
                            .font(.headline)
                        Text(room.status.rawValue.capitalized)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Scanned Rooms")
            .searchable(text: $searchText)
        }
        .onAppear {
            // Load rooms from the persistence repository.
        }
    }
    
    private func filteredRooms() -> [ScannedRoom] {
        if searchText.isEmpty {
            return rooms
        } else {
            return rooms.filter { $0.roomName.localizedCaseInsensitiveContains(searchText) }
        }
    }
}
