# 3D Room Scanner

This project is a SwiftUI-based application leveraging frameworks such as ARKit, RealityKit, and SwiftData to enable users to scan rooms into 3D models using LiDAR sensors. This project showcases software architecture principles including dependency injection, state management, event-driven design, and integration with Apple's ecosystem.

## Architectural Highlights

### Application Entry Point
The application employs SwiftUI’s lifecycle management. It utilizes an `AppDelegate` adaptor to integrate UIKit functionalities such as push notification handling and deep linking into SwiftUI's lifecycle.

### Dependency Injection

The app leverages a Dependency Injection (DI) container pattern. `DIContainer` organizes:
- AppState: Centralized state management using a reactive store (`Store<AppState>`).
- Interactors: Handle business logic (authentication, scanning, permissions).
- Repositories: Separate concerns into local (SwiftData-backed) and remote (web repositories) operations.
- Services: Essential utilities (Keychain, DefaultsService, FileManager).

### State Management

The `AppState` struct manages the application’s global state for authentication, permissions, and view routing.

### Event Handling

- Push Notifications: Managed through `PushNotificationsHandler`, integrating with the scanning workflow, triggering actions based on received notifications.
- Deep Linking: `DeepLinksHandler` directs navigation.

### SwiftData and Persistence

Using SwiftData (`ScanLocalRepository`, `UploadTaskLocalRepository`) for local data persistence ensures efficient management of scans and upload tasks, enabling offline support.

### Networking and Web APIs

The app communicates with AWS services:
- Authentication via AWS Cognito (OAuth 2.0 flow).
- File uploads and data retrieval leveraging presigned URLs and RESTful APIs.
- Push notifications registration managed through a dedicated web repository.

### Authentication

Implements an authentication flow using AWS Cognito, supporting token exchange and KeyChain storage.

### Scanning and 3D Model Handling

- Captures and processes LiDAR scans using ARKit and RealityKit.
- Handles asynchronous upload and processing statuses, ensuring error handling and recovery mechanisms.

### User Interface

Features search, sort, and responsive UI elements integrated with state management.

### Permissions

Manages user permission status checks for camera and push notifications.

## Technical Stack

- SwiftUI: For reactive, declarative UI.
- SwiftData: Local data persistence.
- ARKit & RealityKit: 3D scanning and rendering.
- Combine & Concurrency: Reactive data flows and asynchronous operations.
- AWS: Cloud storage, authentication, and backend services.
- Dependency Injection: Modular, maintainable, and testable architecture.

## Key Features

- 3D scanning using LiDAR.
- Secure authentication and session management.
- Push notification-driven workflow.
- Local data persistence.
- Intuitive and accessible user interface.

## Testing

The project includes unit tests covering local persistence, authentication, and networking logic. The project leverages the Swift Testing framework for modern, concise, and expressive test definitions.
