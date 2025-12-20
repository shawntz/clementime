# Xcode Project Setup Guide

Since the Xcode project file (.xcodeproj) cannot be created via CLI, follow these steps to create it manually in Xcode.

## Creating the Xcode Project

1. **Open Xcode**
2. **File → New → Project**
3. **Select macOS → App**
4. **Click Next**

### Project Configuration

**Product Name**: `ClemenTime`
**Team**: Select your Apple Developer team
**Organization Identifier**: `com.shawnschwartz`
**Bundle Identifier**: `com.shawnschwartz.clementime` (auto-generated)
**Interface**: SwiftUI
**Language**: Swift
**Storage**: Core Data ✅ (check this box)
**Include Tests**: ✅ (check this box)

5. **Click Next**
6. **Save to**: `/Users/shawn.schwartz/Developer/Projects/clementime/clementime-mac`
7. **Click Create**

## Import Existing Files

After creating the project, you need to import the files that were already created:

### 1. Delete Auto-Generated Files

Xcode will create some default files. Delete these (move to trash):
- `ClemenTimeApp.swift` (we have a better version)
- `ContentView.swift` (we have a better version)
- `ClemenTime.xcdatamodeld` (we'll recreate with correct entities)

### 2. Add Existing Files to Project

**Right-click on the ClemenTime folder** in the Project Navigator → **Add Files to "ClemenTime"**

Add these directories (make sure "Create folder references" is selected):
- `Core/` directory
- `Data/` directory (except PersistenceController.swift needs updating)
- `Views/` directory
- `ViewModels/` directory (create empty if needed)
- `Services/` directory (create empty if needed)
- `Resources/` directory

For individual files in the root:
- Select and add: `ClemenTimeApp.swift`, `ContentView.swift`

### 3. Update PersistenceController

Open `Data/CoreData/PersistenceController.swift` and ensure the data model name matches:

```swift
container = NSPersistentCloudKitContainer(name: "ClemenTime")
```

### 4. Create Core Data Model

Follow the detailed instructions in `CORE_DATA_MODEL_SETUP.md` to create the Core Data model file with all entities.

## Configure Capabilities

### 1. Add iCloud Capability

- Select the **ClemenTime project** in Project Navigator
- Select the **ClemenTime target**
- Go to **Signing & Capabilities** tab
- Click **+ Capability**
- Add **iCloud**
- Check ✅ **CloudKit**
- Click **+** under Containers
- Enter: `iCloud.com.shawnschwartz.clementime`

### 2. Add Background Modes

- Still in **Signing & Capabilities**
- Click **+ Capability**
- Add **Background Modes**
- Check ✅ **Remote notifications**

### 3. Add Microphone Permission

The microphone permission is already in `Info.plist` with key:
- `NSMicrophoneUsageDescription`

### 4. Configure Signing

- Still in **Signing & Capabilities**
- Under **Signing**:
  - **Automatically manage signing**: ✅ Check this
  - **Team**: Select your Apple Developer team
  - **Bundle Identifier**: `com.shawnschwartz.clementime`

## Project Structure in Xcode

After setup, your Project Navigator should look like this:

```
ClemenTime/
├── ClemenTimeApp.swift
├── ContentView.swift
├── Info.plist
├── Core/
│   └── Domain/
│       ├── Entities/
│       │   ├── Course.swift
│       │   ├── Cohort.swift
│       │   ├── ExamSession.swift
│       │   ├── Student.swift
│       │   ├── Section.swift
│       │   ├── ExamSlot.swift
│       │   ├── ExamSlotHistory.swift
│       │   ├── Constraint.swift
│       │   ├── Recording.swift
│       │   └── TAUser.swift
│       ├── Repositories/
│       ├── UseCases/
│       └── Services/
│           └── PermissionChecker.swift
├── Data/
│   ├── CoreData/
│   │   ├── ClemenTime.xcdatamodeld
│   │   └── PersistenceController.swift
│   ├── Repositories/
│   └── CloudKit/
├── Views/
│   └── Course/
│       └── CourseDetailView.swift
├── ViewModels/
├── Services/
└── Resources/
    └── Assets.xcassets/
```

## Build Settings

Recommended build settings:

### General Tab
- **Deployment Target**: macOS 14.0
- **Supported Destinations**: Mac (Designed for Mac)

### Build Settings Tab
- **Swift Language Version**: Swift 5
- **Other Swift Flags**: Add `-strict-concurrency=complete` for async/await safety

## CloudKit Dashboard Setup

1. **Open CloudKit Dashboard**: https://icloud.developer.apple.com/dashboard/
2. **Select Container**: `iCloud.com.shawnschwartz.clementime`
3. **Development Environment** (for testing):
   - Xcode will automatically create schema when you first run
   - Use **Editor → Prepare for CloudKit** in Xcode to sync schema

4. **Before Production**:
   - Test thoroughly in Development
   - Deploy schema to Production when ready
   - ⚠️ **Production schema cannot be easily modified once deployed**

## Running the App

1. **Select Target**: ClemenTime
2. **Select Destination**: My Mac
3. **Press Cmd+R** or click the Run button

### First Run Issues

If you encounter signing issues:
- Check that your Apple ID is signed in (Xcode → Settings → Accounts)
- Ensure your team is selected
- Try cleaning build folder (Product → Clean Build Folder)

If CloudKit issues occur:
- Ensure you're signed into iCloud on your Mac
- Check iCloud capability is properly configured
- Verify container identifier matches in both:
  - Xcode project capabilities
  - PersistenceController.swift
  - Info.plist

## Testing

### Unit Tests

Create test files in `ClemenTimeTests/`:
- Test entities: `CourseTests.swift`, `StudentTests.swift`, etc.
- Test use cases: `GenerateScheduleUseCaseTests.swift`
- Test repositories: `CourseRepositoryTests.swift`

Run tests: **Cmd+U**

### UI Tests

Create UI test files in `ClemenTimeUITests/`:
- Test course creation flow
- Test schedule generation
- Test student import

Run UI tests: **Cmd+U** with UI tests selected

## Development Tips

### Using Previews

Add SwiftUI previews to your views for rapid development:

```swift
#Preview {
    ContentView()
        .environmentObject(AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
```

### Debugging Core Data

Enable Core Data debug output:
1. **Product → Scheme → Edit Scheme**
2. **Run → Arguments**
3. **Add argument**: `-com.apple.CoreData.SQLDebug 1`

### CloudKit Console Logging

Add to see CloudKit operations:
- **Add argument**: `-com.apple.coredata.cloudkit.logging 1`

## Troubleshooting

### "No such module 'CloudKit'"
- Ensure iCloud capability is enabled
- Clean build folder and rebuild

### "Container not found"
- Check container identifier spelling
- Ensure signed in to iCloud
- Container must exist in CloudKit Dashboard

### Core Data model errors
- Ensure model name matches in PersistenceController
- Check all entity names are correct
- Verify relationships are set up properly

### Build errors on import
- Check all imports are correct (SwiftUI, Foundation, CoreData, CloudKit)
- Ensure target membership is set for all files
- Verify deployment target is set to macOS 14.0+

## Next Steps

After completing this setup:

1. ✅ Verify the app builds and runs
2. 📝 Create the Core Data model (see CORE_DATA_MODEL_SETUP.md)
3. 🧪 Run existing tests
4. 📱 Test iCloud sync on multiple devices
5. 🚀 Begin implementing repositories and use cases

---

If you encounter any issues, refer to:
- [Apple's Core Data Documentation](https://developer.apple.com/documentation/coredata)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
