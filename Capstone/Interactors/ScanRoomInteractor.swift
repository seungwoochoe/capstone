//
//  ScanRoomInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol ScanRoomInteractor {
    
}

struct RealScanRoomInteractor: ScanRoomInteractor {
    let scanUploadTaskDBRepository: ScanUploadTaskDBRepository
    
    func startScanning() {
        
    }
}

struct StubScanRoomInteractor: ScanRoomInteractor {
    
}
