# CloudKit Sharing Implementation Guide

## Overview

ClemenTime uses CloudKit's built-in sharing functionality to enable course creators (admins) to invite teaching assistants (TAs) as collaborators. This document explains how the sharing system works and how to use it.

## Architecture

### Key Components

1. **CloudKitShareManager** (`Data/CloudKit/CloudKitShareManager.swift`)
   - Handles all CloudKit sharing operations
   - Creates and manages `CKShare` objects
   - Adds/removes participants
   - Manages share acceptance

2. **CourseRepository** (sharing methods)
   - `shareCourse()` - Create share and invite collaborator
   - `acceptShare()` - Accept share invitation

3. **TAUserRepository**
   - Manages TA user records
   - Stores custom permissions per TA

4. **Use Cases**
   - `ShareCourseUseCase` - Full workflow for inviting a collaborator
   - `AcceptShareUseCase` - Full workflow for accepting an invitation
   - `RemoveCollaboratorUseCase` - Remove a collaborator from a course

## How Sharing Works

### 1. Creating a Share (Admin Workflow)

When an admin invites a TA:

```swift
// 1. Admin provides collaborator details
let input = ShareCourseInput(
    courseId: course.id,
    collaboratorEmail: "ta@university.edu",
    collaboratorFirstName: "John",
    collaboratorLastName: "Doe",
    role: .ta,
    permissions: [.viewSchedules, .editSchedules, .recordExams]
)

// 2. Execute use case
let useCase = ShareCourseUseCase(
    courseRepository: courseRepo,
    taUserRepository: taUserRepo
)
let output = try await useCase.execute(input: input)

// 3. Send share URL to collaborator
let shareURL = output.shareURL
// Email this URL to the collaborator
```

**What happens behind the scenes:**

1. Course record is fetched from CloudKit Private Database
2. A `CKShare` is created with the course as the root record
3. Collaborator is looked up by email (they must have an iCloud account)
4. Collaborator is added to the share with read/write permission
5. A `TAUser` record is created with custom permissions
6. Share URL is returned for distribution (via email/Slack)

### 2. Accepting a Share (Collaborator Workflow)

When a TA receives the share URL:

```swift
// 1. User opens share URL (handled by system)
// System provides CKShare.Metadata

// 2. Accept the share
let input = AcceptShareInput(shareMetadata: metadata)
let useCase = AcceptShareUseCase(
    courseRepository: courseRepo,
    taUserRepository: taUserRepo
)
let output = try await useCase.execute(input: input)

// 3. Course is now available
let sharedCourse = output.course
let myRole = output.myRole // .ta or .admin
```

**What happens behind the scenes:**

1. Share is accepted in CloudKit
2. Course record becomes available in Shared CloudKit Database
3. NSPersistentCloudKitContainer automatically syncs course to Core Data
4. TA's permission record is fetched
5. TA can now access course based on their permissions

### 3. Removing a Collaborator (Admin Workflow)

When an admin wants to revoke access:

```swift
let input = RemoveCollaboratorInput(
    courseId: course.id,
    taUserId: ta.id,
    currentUserId: currentUser.id
)

let useCase = RemoveCollaboratorUseCase(
    courseRepository: courseRepo,
    taUserRepository: taUserRepo,
    shareManager: shareManager
)

try await useCase.execute(input: input)
```

**What happens:**

1. Permission check (only course creator can remove)
2. TA user record is fetched to get email
3. Participant is removed from CKShare
4. TA immediately loses access to the course
5. TAUser record is deleted

## Permission System

### CloudKit Permissions (Infrastructure Level)

CloudKit provides basic permissions:
- **Owner**: Course creator (full control)
- **Read/Write**: Collaborators (can read and modify)

### App-Level Permissions (Business Logic)

ClemenTime implements granular permissions on top of CloudKit:

| Permission Type | Description | Default for TAs |
|----------------|-------------|-----------------|
| `viewSchedules` | View exam schedules | ✅ Yes |
| `editSchedules` | Modify exam slots | ✅ Yes |
| `recordExams` | Upload recordings | ✅ Yes |
| `manageStudents` | Add/edit/delete students | ❌ No |
| `manageConstraints` | Edit student constraints | ❌ No |
| `exportData` | Export CSV | ❌ No |
| `manageSettings` | Edit course settings | ❌ No |
| `inviteCollaborators` | Share with other TAs | ❌ No |

**Permission Enforcement:**

```swift
// Check permission before action
let checker = PermissionChecker(currentUser: taUser, course: course)

if checker.can(.editSchedules) {
    // Allow schedule editing
} else {
    // Show permission denied error
}
```

**Admins** (course creators) always have all permissions, regardless of their permission settings.

## Database Structure

### CloudKit Databases

1. **Private Database**
   - Contains courses created by the user
   - User is the owner
   - Can create shares

2. **Shared Database**
   - Contains courses shared with the user
   - User is a participant
   - Read/write access via share

### Record Zones

Each course uses a separate `CKRecordZone` for:
- Atomic operations
- Efficient sync subscriptions
- Isolation between courses

## Sync Behavior

### Automatic Sync

NSPersistentCloudKitContainer handles:
- ✅ Creating CloudKit records for new Core Data entities
- ✅ Updating CloudKit when Core Data changes
- ✅ Fetching CloudKit changes to Core Data
- ✅ Conflict resolution (last-write-wins)

### Manual Sync (when needed)

For immediate sync:

```swift
let container = PersistenceController.shared.container

// Trigger export (Core Data → CloudKit)
try await container.persistentStoreCoordinator.persistentStores.forEach { store in
    try container.persistentStoreCoordinator.setMetadata(
        ["NSPersistentStoreRemoteChangeKey": Date()],
        for: store
    )
}

// Import happens automatically via notifications
```

## Testing Sharing

### Prerequisites

1. Two iCloud accounts (admin and TA)
2. Both users must be signed into iCloud on their devices
3. CloudKit container must be configured in Xcode

### Test Flow

1. **Admin Account**
   - Create a course
   - Invite collaborator with TA's iCloud email
   - Get share URL

2. **TA Account**
   - Receive share URL (via email, Messages, etc.)
   - Open share URL
   - Accept share
   - Verify course appears in app

3. **Permission Testing**
   - TA tries to perform actions
   - Verify permissions are enforced
   - Admin adjusts permissions
   - Verify changes take effect

4. **Removal Testing**
   - Admin removes TA
   - Verify TA loses access immediately
   - Verify course disappears from TA's device

## Troubleshooting

### Share Creation Fails

**Error: "Participant not found"**
- Collaborator email must match their iCloud account email
- They must be signed into iCloud
- Try using icloud.com email directly

**Error: "Share save failed"**
- Check network connection
- Verify CloudKit container is properly configured
- Ensure course record exists in CloudKit

### Share Acceptance Fails

**Share URL doesn't open app**
- Verify app's associated domains are configured
- Check CloudKit container identifier matches
- Try copying URL and pasting in Safari

**Course doesn't appear after accepting**
- Wait a few seconds for sync
- Force quit and reopen app
- Check iCloud sync is enabled in Settings

### Permission Issues

**TA has wrong permissions**
- Verify TAUser record was created
- Check permissionsJSON field is valid
- Admin can update permissions anytime

**Changes don't sync**
- Check both users are online
- Verify iCloud sync is working (Settings → iCloud → iCloud Drive)
- Force sync by making a small change

## Implementation Checklist

When implementing sharing in UI:

- [ ] Create "Invite Collaborator" button in course settings
- [ ] Form to collect: email, name, permissions
- [ ] Display share URL (with copy button)
- [ ] Email/Message share option
- [ ] List of current collaborators
- [ ] Remove collaborator button
- [ ] Edit permissions for existing TAs
- [ ] Accept share flow when app opens share URL
- [ ] Show permission-denied errors gracefully
- [ ] Indicate shared courses in UI (e.g., with icon)

## Security Considerations

### Data Access

- ✅ Only invited collaborators can access shared courses
- ✅ Course creator can revoke access anytime
- ✅ Permissions are enforced at app level
- ✅ CloudKit provides encryption at rest and in transit

### Best Practices

1. **Validate email addresses** before creating shares
2. **Confirm removal** before revoking access
3. **Audit permissions** regularly
4. **Use granular permissions** - don't give TAs more access than needed
5. **Test sharing** thoroughly before production

## Future Enhancements

Potential improvements:

- [ ] Role templates (e.g., "Head TA", "Section TA")
- [ ] Bulk invite multiple TAs
- [ ] Share analytics (who accessed when)
- [ ] Temporary access (expires after date)
- [ ] Share via QR code
- [ ] In-app invitation flow (no email needed)
- [ ] Permission change notifications

## References

- [CloudKit Sharing Documentation](https://developer.apple.com/documentation/cloudkit/shared_records)
- [CKShare API](https://developer.apple.com/documentation/cloudkit/ckshare)
- [NSPersistentCloudKitContainer](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)
