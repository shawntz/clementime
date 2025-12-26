# Core Data Model Setup Guide

This guide explains how to manually create the Core Data model in Xcode since it cannot be created via CLI.

## Creating the Data Model File

1. **Open Xcode** and navigate to the ClemenTime project
2. **Right-click on the ClemenTime/Data/CoreData folder**
3. **Select New File → Core Data → Data Model**
4. **Name it: ClemenTime.xcdatamodeld**
5. **Click Create**

## Entity Configuration

For each entity below, create it in the Core Data model editor with the following attributes and relationships:

### 1. CourseEntity

**Attributes:**
- `id`: UUID
- `name`: String
- `term`: String
- `quarterStartDate`: Date
- `examDay`: String
- `totalExams`: Integer 16
- `isActive`: Boolean (default: YES)
- `createdByUserId`: UUID
- `settingsJSON`: String

**Relationships:**
- `cohorts`: To-Many → CohortEntity (cascade delete)
- `examSessions`: To-Many → ExamSessionEntity (cascade delete)
- `sections`: To-Many → SectionEntity (cascade delete)
- `students`: To-Many → StudentEntity (cascade delete)
- `taUsers`: To-Many → TAUserEntity (cascade delete)

**Indexes:**
- id (unique)
- name

### 2. CohortEntity

**Attributes:**
- `id`: UUID
- `courseId`: UUID
- `name`: String
- `weekType`: String
- `colorHex`: String
- `sortOrder`: Integer 16

**Relationships:**
- `course`: To-One → CourseEntity
- `sections`: To-Many → SectionEntity
- `students`: To-Many → StudentEntity

**Indexes:**
- id (unique)
- courseId, sortOrder (compound)

### 3. ExamSessionEntity

**Attributes:**
- `id`: UUID
- `courseId`: UUID
- `examNumber`: Integer 16
- `oddWeekDate`: Date
- `evenWeekDate`: Date
- `theme`: String (optional)
- `startTime`: String
- `endTime`: String
- `durationMinutes`: Integer 16
- `bufferMinutes`: Integer 16

**Relationships:**
- `course`: To-One → CourseEntity
- `examSlots`: To-Many → ExamSlotEntity (cascade delete)

**Indexes:**
- id (unique)
- courseId, examNumber (compound, unique)

### 4. SectionEntity

**Attributes:**
- `id`: UUID
- `courseId`: UUID
- `code`: String
- `name`: String
- `location`: String
- `assignedTAId`: UUID (optional)
- `cohortId`: UUID
- `isActive`: Boolean (default: YES)

**Relationships:**
- `course`: To-One → CourseEntity
- `cohort`: To-One → CohortEntity
- `assignedTA`: To-One → TAUserEntity (optional)
- `students`: To-Many → StudentEntity (cascade delete)
- `examSlots`: To-Many → ExamSlotEntity (cascade delete)

**Indexes:**
- id (unique)
- courseId, code (compound, unique)

### 5. StudentEntity

**Attributes:**
- `id`: UUID
- `courseId`: UUID
- `sectionId`: UUID
- `sisUserId`: String
- `email`: String
- `fullName`: String
- `cohortId`: UUID
- `slackUserId`: String (optional)
- `slackUsername`: String (optional)
- `isActive`: Boolean (default: YES)

**Relationships:**
- `course`: To-One → CourseEntity
- `section`: To-One → SectionEntity
- `cohort`: To-One → CohortEntity
- `examSlots`: To-Many → ExamSlotEntity (cascade delete)
- `constraints`: To-Many → ConstraintEntity (cascade delete)
- `recordings`: To-Many → RecordingEntity (cascade delete)

**Indexes:**
- id (unique)
- courseId, sisUserId (compound, unique)
- email

### 6. ExamSlotEntity

**Attributes:**
- `id`: UUID
- `courseId`: UUID
- `studentId`: UUID
- `sectionId`: UUID
- `examSessionId`: UUID
- `date`: Date
- `startTime`: Date
- `endTime`: Date
- `isScheduled`: Boolean (default: NO)
- `isLocked`: Boolean (default: NO)
- `notes`: String (optional)

**Relationships:**
- `course`: To-One → CourseEntity
- `student`: To-One → StudentEntity
- `section`: To-One → SectionEntity
- `examSession`: To-One → ExamSessionEntity
- `recording`: To-One → RecordingEntity (optional, nullify)
- `histories`: To-Many → ExamSlotHistoryEntity (cascade delete)

**Indexes:**
- id (unique)
- studentId, examSessionId (compound, unique)
- courseId, date

### 7. ExamSlotHistoryEntity

**Attributes:**
- `id`: UUID
- `examSlotId`: UUID
- `studentId`: UUID
- `sectionId`: UUID
- `examNumber`: Integer 16
- `weekNumber`: Integer 16
- `date`: Date (optional)
- `startTime`: Date (optional)
- `endTime`: Date (optional)
- `isScheduled`: Boolean
- `changedAt`: Date
- `changedBy`: String
- `reason`: String

**Relationships:**
- `examSlot`: To-One → ExamSlotEntity
- `student`: To-One → StudentEntity
- `section`: To-One → SectionEntity

**Indexes:**
- id (unique)
- examSlotId, changedAt (compound)

### 8. ConstraintEntity

**Attributes:**
- `id`: UUID
- `studentId`: UUID
- `constraintType`: String
- `constraintValue`: String
- `constraintDescription`: String
- `isActive`: Boolean (default: YES)

**Relationships:**
- `student`: To-One → StudentEntity

**Indexes:**
- id (unique)
- studentId, constraintType (compound)

### 9. RecordingEntity

**Attributes:**
- `id`: UUID
- `examSlotId`: UUID
- `studentId`: UUID
- `taUserId`: UUID
- `recordedAt`: Date
- `uploadedAt`: Date (optional)
- `duration`: Double
- `fileSize`: Integer 64
- `localFileURL`: String (optional)
- `iCloudAssetName`: String (optional)

**Relationships:**
- `examSlot`: To-One → ExamSlotEntity (unique)
- `student`: To-One → StudentEntity
- `taUser`: To-One → TAUserEntity

**Indexes:**
- id (unique)
- examSlotId (unique)
- studentId

### 10. TAUserEntity

**Attributes:**
- `id`: UUID
- `courseId`: UUID
- `firstName`: String
- `lastName`: String
- `email`: String
- `username`: String
- `role`: String
- `permissionsJSON`: String
- `location`: String
- `slackId`: String (optional)
- `isActive`: Boolean (default: YES)

**Relationships:**
- `course`: To-One → CourseEntity
- `sections`: To-Many → SectionEntity
- `recordings`: To-Many → RecordingEntity

**Indexes:**
- id (unique)
- courseId, email (compound, unique)
- username

## CloudKit Configuration

After creating the entities:

1. **Select the Data Model file** in Xcode
2. **Editor → Create NSManagedObject Subclass**
3. **Generate all entities**
4. **Enable CloudKit:**
   - Select the project in Xcode
   - Go to Signing & Capabilities
   - Add "iCloud" capability
   - Enable "CloudKit"
   - Add container: `iCloud.com.shawnschwartz.clementime`
   - Enable "Background Modes" capability
   - Check "Remote notifications"

5. **Configure CloudKit Schema:**
   - In Xcode: Editor → Prepare for Deployment → CloudKit
   - This will sync the Core Data model to CloudKit

## Important Notes

- All entities must have unique `id` attributes for CloudKit sync
- Use cascade delete rules to maintain referential integrity
- Enable history tracking for sync (already configured in PersistenceController)
- Test thoroughly before deploying to production CloudKit container
