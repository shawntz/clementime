# ClemenTime Mac App

A native macOS application for managing oral exam schedules with iCloud sync and flexible course structures.

## Features

- **Flexible Course Structure**: Create courses with unlimited custom cohorts (not limited to A, B, C)
- **Exam Session Management**: Configure any number of exam sessions with custom themes
- **Smart Scheduling**: Automated exam slot generation with constraint handling
- **Custom Permissions**: Granular access control for TAs and admins
- **iCloud Sync**: Seamless data synchronization across devices with CloudKit
- **Course Sharing**: Invite TAs to collaborate on courses with custom permission levels
- **Student Management**: Import rosters from CSV, manage constraints, track history
- **Audio Recording**: Record exams directly in the app with iCloud storage
- **Offline Support**: Work offline with automatic sync when online

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for development)
- Active iCloud account
- Apple Developer account (for CloudKit configuration)

## Getting Started

### Development Setup

1. **Open the project in Xcode:**
   ```bash
   cd clementime-mac
   open ClemenTime.xcodeproj
   ```

2. **Configure CloudKit:**
   - Follow the instructions in `CORE_DATA_MODEL_SETUP.md` to create the Core Data model
   - Add iCloud capability in Xcode (Signing & Capabilities tab)
   - Container ID: `iCloud.com.shawnschwartz.clementime`
   - Enable "CloudKit" and "Remote notifications"

3. **Set up Code Signing:**
   - Select your development team in the project settings
   - Bundle Identifier: `com.shawnschwartz.clementime`

4. **Build and Run:**
   - Press Cmd+R or click the Run button in Xcode

### First-Time Setup

When you first launch the app:

1. Sign in with your iCloud account (if prompted)
2. Grant microphone permission for exam recordings
3. Create your first course using the "New Course" button
4. Add cohorts, exam sessions, and configure settings
5. Import your student roster from a CSV file
6. Generate the exam schedule

## Architecture

The app follows Clean Architecture with MVVM pattern:

```
Presentation Layer (SwiftUI Views + ViewModels)
    ↓
Domain Layer (Entities, Use Cases, Repositories)
    ↓
Data Layer (Core Data, CloudKit, Repositories)
    ↓
Infrastructure (File System, AVFoundation)
```

### Key Components

- **Domain Entities**: Pure Swift models (Course, Student, ExamSlot, etc.)
- **Core Data**: Local persistence with CloudKit sync
- **Repositories**: Abstract data access layer
- **Use Cases**: Business logic (GenerateScheduleUseCase, ImportRosterUseCase, etc.)
- **ViewModels**: UI state management with @Published properties
- **Views**: SwiftUI declarative UI

## Project Structure

```
ClemenTime/
├── ClemenTimeApp.swift          # Main app entry point
├── ContentView.swift             # Root navigation view
├── Core/
│   └── Domain/
│       ├── Entities/             # Domain models
│       ├── Repositories/         # Repository protocols
│       ├── UseCases/             # Business logic
│       └── Services/             # Permission checker, etc.
├── Data/
│   ├── CoreData/                 # Core Data stack
│   ├── Repositories/             # Repository implementations
│   └── CloudKit/                 # CloudKit sharing logic
├── Views/                        # SwiftUI views
├── ViewModels/                   # View models
├── Services/                     # Audio recording, CSV export
└── Resources/                    # Assets, localization
```

## Core Concepts

### Cohorts

Unlike traditional odd/even week systems, ClemenTime allows unlimited custom cohorts:

```
Course: PSYCH 10 Fall 2025
├── Cohort A (Odd Week, Blue)
├── Cohort B (Even Week, Green)
└── Cohort C (Odd Week, Orange)
```

Each cohort can have independent dates for the same exam session.

### Exam Sessions

Configure flexible exam sessions with:
- Custom exam numbers (not limited to 5)
- Themes/labels (e.g., "Foundational Questions", "Midterm")
- Independent dates for each cohort
- Time range and duration settings

### Constraints

Students can have scheduling constraints:
- **Time Before**: Must finish before specific time
- **Time After**: Must start after specific time
- **Week Preference**: Prefers odd or even weeks
- **Specific Date**: Must be on exact date
- **Exclude Date**: Cannot be on specific date

### Permissions

Custom permission system with granular control:
- View Schedules
- Edit Schedules
- Record Exams
- Manage Students
- Manage Constraints
- Export Data
- Manage Settings
- Invite Collaborators

Admins have all permissions; TAs have customizable permissions.

## Data Migration

To migrate data from the Rails web app (optional):

1. Export data from Rails as JSON via API
2. Use the migration service (to be implemented)
3. Import into the Mac app

Alternatively, start fresh and import student rosters from CSV.

## Testing

Run tests in Xcode:
```bash
Cmd+U
```

Tests are organized by layer:
- Domain Layer: Unit tests for entities and use cases
- Data Layer: Integration tests for Core Data and CloudKit
- UI Layer: SwiftUI view tests

## Deployment

### TestFlight

1. Archive the app in Xcode (Product → Archive)
2. Upload to App Store Connect
3. Invite beta testers via TestFlight

### Mac App Store

1. Complete App Store metadata in App Store Connect
2. Submit for review
3. Publish when approved

### Direct Distribution

1. Archive and export as Developer ID application
2. Notarize with Apple
3. Distribute the .app bundle

## Contributing

This is a personal project for managing oral exam schedules. Contributions welcome!

## License

[Add your license here]

## Acknowledgments

Migrated from ClemenTime Rails/React web app with enhanced features for macOS.

## Support

For questions or issues, please contact [your email or create GitHub issues].

---

Built with ❤️ using Swift, SwiftUI, Core Data, and CloudKit
