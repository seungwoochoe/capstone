# 3D Room Scanner

This project is a SwiftUI-based application leveraging frameworks such as ARKit, RealityKit, and SwiftData to enable users to scan rooms into 3D models using LiDAR sensors. The primary goal is for users to scan a room with their iOS device, upload the data to a server, download the processed result, view it, and export it elsewhere.

The project showcases software architecture principles including dependency injection, state management, event-driven design, and integration with Apple’s ecosystem. A clean architecture is used, dividing features by clear responsibility to improve maintainability and testability.

## Project Goals

- Room Scanning: Allow users to scan indoor spaces using LiDAR via their iOS device.
- Data Upload: Upload scan data to a backend server for processing.
- Result Download & Export: Download processed 3D models, view them, and export to other destinations.

## Architectural Overview

The architecture consists of the following layers:

- Presentation
- App State
- Interactor
- Repository & Services

Each layer is responsible for a distinct part of the app’s logic, maximizing independence, clarity, and testability.

### Layer Responsibilities

- Presentation (SwiftUI View): Handles all user input and display logic. Views subscribe to state changes using reactive programming with the Combine framework. Views access dependencies via injection from the DIContainer, ensuring loose coupling.
- App State: Centralizes global state, including authentication status, permissions, and scan lists. Views reactively respond to state changes.
- Interactor: Contains all business logic, completely unaware of the view or repository implementation. This separation ensures that business logic can be tested and maintained in isolation.
- Repository: Abstracts both local and remote data operations. The repository pattern means interactors interact only with protocols, not concrete implementations. This abstraction allows swapping storage implementations with zero changes to business logic.

### Dependency Injection

All dependencies are assembled in `AppEnvironment.bootstrap()`, which configures the DIContainer with:

- Global state (`AppState`)
- Interactors (business logic handlers)
- Repositories (local and remote)
- Services (e.g., Keychain, file management)

Dependencies are injected into the SwiftUI view hierarchy, making them accessible in the app.

### Lifecycle and System Event Handling

The app uses SwiftUI life cycle, supplemented by a UIKit `AppDelegate` adapter for system integrations like push notifications and deep linking.

- Push Notifications: Managed by `PushNotificationsHandler`, which can trigger workflow actions in response to notifications.
- Deep Linking: Managed by `DeepLinksHandler` for in-app navigation.

### Permissions Management

The app centrally checks and updates the status for camera and push notification permissions, surfacing them in AppState for use across the UI.

### 3D Scanning & Model Handling

- Scanning uses ARKit and RealityKit to process LiDAR data into 3D models.
- Upload and download of scans are tracked, with persistent state maintained even across app restarts.

### Data Persistence

- SwiftData is used for local persistence of scan and upload tasks, supporting offline use.
- Repositories isolate data access, so changing the persistence backend requires no change to business logic.

### Networking & Cloud Integration

  - Authentication is handled via AWS Cognito using OAuth 2.0, with tokens securely stored in Keychain.
  - File uploads and downloads use presigned URLs and REST APIs.
  - Push notification registration is managed by a dedicated web repository.

## Design Rationale

The architecture offers several advantages:

- Separation of Concerns: Each layer only knows about its own responsibility. This reduces the impact of changes and makes the code easier to read and maintain.
- Flexibility: Switching out networking or data storage implementations does not require changes in the business logic.
- Testability: Dependency injection allows the use of mock objects for each layer, enabling unit testing without relying on real network or database dependencies.
- Maintainability: Clean architecture enables easier addition of new features or modifications with minimal impact on unrelated code.

## Technical Stack

- SwiftUI: Declarative user interface.
- SwiftData: Local data persistence.
- ARKit & RealityKit: LiDAR scanning and 3D rendering.
- Combine & Swift Concurrency: Reactive programming and asynchronous operations.
- AWS: Authentication, storage, and backend services.
- Dependency Injection: Promotes modular, maintainable, and testable codebase.

## Key Features

- 3D room scanning using LiDAR.
- Secure authentication and session management.
- Push notification-driven workflows.
- Local data persistence and offline support.
- Intuitive, accessible, and responsive UI.

## Testing

The project includes unit tests covering:

- Local data persistence
- Authentication
- Networking logic

Dependency injection makes it possible to test each layer in isolation with mock implementations, without reliance on actual network or database access.
