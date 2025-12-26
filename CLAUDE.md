# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clementime is a multi-platform oral exam scheduler for universities with **two independent implementations**:

1. **Web App** (`/clementime-web`): Rails 8.1.1 + React 19 + PostgreSQL
   - Status: Stable production deployment (maintenance mode)
   - Deployment: Docker, Render.com

2. **macOS App** (`/clementime-mac`): Swift 5.9+ + SwiftUI + CloudKit
   - Status: Active development
   - Requirements: macOS 15.0+, Xcode 15+

Both platforms share the same core scheduling algorithm but operate completely independently with no shared data layer.

## Common Development Commands

### Web App (`/clementime-web`)

```bash
# Initial setup
cd clementime-web
bin/setup                              # Install all dependencies + setup DB

# Development
bin/dev                                # Start Rails API + React dev server
make dev                               # Alternative: Docker Compose dev environment
make dev-logs                          # View container logs
make dev-stop                          # Stop development environment

# Database
make db-setup                          # Create, migrate, seed
make db-migrate                        # Run migrations only
make db-reset                          # DESTRUCTIVE: Reset database
bundle exec rails console              # Rails console
make console                           # Rails console (Docker)

# Testing & Linting
make test                              # Run test suite
make lint                              # RuboCop linting
make lint-fix                          # Auto-fix lint issues

# Build & Deploy
make build                             # Build Docker image
make push                              # Push to Docker Hub
make deploy-render                     # Deploy to Render (via git push)
```

### macOS App (`/clementime-mac`)

```bash
# Development
cd clementime-mac
open Clementime/Clementime.xcodeproj   # Open in Xcode (recommended)

# Command-line builds
xcodebuild -scheme Clementime -configuration Debug     # Debug build
xcodebuild -scheme Clementime -configuration Release   # Release build
xcodebuild test -scheme Clementime                     # Run tests

# Linting
swiftlint                              # Lint Swift code (.swiftlint.yml config)
```

### Repository-Level Commands

```bash
# Version & Release (run from repo root)
./scripts/release.sh                   # Patch version bump + GitHub release
./scripts/release.sh minor             # Minor version bump
./scripts/release.sh major             # Major version bump

# The release script automatically:
# - Builds Docker image for web app
# - Builds macOS DMG installer
# - Creates GitHub release with changelog
# - Pushes to Docker Hub
```

## Architecture

### Web App Architecture (Rails + React)

**Backend** (`/clementime-web/app`):
- **MVC Pattern**: Rails controllers → services → models
- **API Structure**: `/api/admin/*` (admin endpoints), `/api/ta/*` (TA endpoints)
- **Key Services**:
  - `ScheduleGenerator` (697 lines): Core constraint-based scheduling algorithm
  - `CanvasRosterImporter`: LMS roster imports
  - `SlackNotifier`, `SlackMatcher`: Real-time Slack notifications
  - `CloudflareR2Uploader`: File storage
- **Database**: PostgreSQL (8 main tables: constraints, exam_slots, exam_slot_histories, sections, students, recordings, system_configs, users)
- **Caching**: Redis + Solid Cache/Queue/Cable (Rails 8 Omakase)

**Frontend** (`/clementime-web/client`):
- **Framework**: React 19.1.1 with Vite 7.1.11
- **Styling**: Tailwind CSS 3
- **Routing**: React Router 7.9.3
- **HTTP**: Axios for API calls
- **State**: React Context API

### macOS App Architecture (Swift + SwiftUI)

**Clean Architecture** with strict layer separation:

```
Presentation Layer (Views + ViewModels)
    ↓
Domain Layer (UseCases + Repositories + Entities + Services)
    ↓
Data Layer (Core Data + CloudKit + Repository Implementations)
```

**Key Patterns**:
- **MVVM**: ViewModels handle presentation logic, Views are pure SwiftUI
- **Repository Pattern**: Abstract data access via protocol-based repositories
- **Dependency Injection**: Manual DI container (`DependencyContainer.swift`)
- **Use Cases**: Single-responsibility application logic (e.g., `GenerateScheduleUseCase`, `ShareCourseUseCase`)
- **Entity Mapping**: Core Data entities ↔ Domain entities via explicit mappers (`*Entity+Mapping.swift`)

**Core Data Stack** (`/clementime-mac/Clementime/Clementime/Data/CoreData`):
- Local persistence with offline-first design
- CloudKit integration for automatic iCloud sync
- Mappers handle conversion between Core Data entities and domain models

**Important Files**:
- `DependencyContainer.swift`: Wires up all dependencies (repositories, use cases, etc.)
- `PersistenceController.swift`: Core Data stack initialization
- `CloudKitShareManager.swift`: Course sharing via CloudKit

## Scheduling Algorithm

The core scheduling algorithm is **identical logic** in both platforms (ported from Rails to Swift):

**Location**:
- Web: `/clementime-web/app/services/schedule_generator.rb` (697 lines)
- macOS: `/clementime-mac/Clementime/Clementime/Core/Domain/UseCases/GenerateScheduleUseCase.swift`

### Key Concepts

1. **Cohorts**: Students assigned to "odd" or "even" cohorts (or custom cohorts in macOS)
   - Alternating week scheduling (Exam 1: odd week 1 + even week 2, etc.)

2. **Constraint System** (5 types):
   - `time_before`: Student must finish before specified time
   - `time_after`: Student must start after specified time
   - `week_preference`: Lock student to odd/even weeks only
   - `specific_date`: Force exam on specific date
   - `exclude_date`: Prevent exam on specific date

3. **Prioritization Strategy**:
   - Constrained students scheduled first (deterministic shuffle within groups)
   - Order: `time_before` → `time_after` → date constraints → unconstrained
   - Prevents constraint violations and maximizes scheduling success

4. **Scheduling Logic**:
   - Sequential slot assignment in priority order
   - Time windows respect exam duration + buffer minutes
   - Gap filling: Regeneration attempts to fill gaps in existing schedules
   - Locked slots: Once "sent to students", slots are locked and never regenerated

5. **Configuration** (SystemConfig table for web, UserDefaults for macOS):
   - `EXAM_DAY`: e.g., "friday"
   - `EXAM_START_TIME`: e.g., "13:30"
   - `EXAM_END_TIME`: e.g., "14:50"
   - `EXAM_DURATION_MINUTES`: e.g., 7
   - `EXAM_BUFFER_MINUTES`: e.g., 1
   - `QUARTER_START_DATE`: Start of term
   - `TOTAL_EXAMS`: Max 5 for web, unlimited for macOS
   - `BALANCED_TA_SCHEDULING`: Enable/disable balanced mode

## Data Models

### Web App (PostgreSQL Schema)

Key tables in `/clementime-web/db/schema.rb`:
- `constraints`: Time/date constraints per student per exam
- `exam_slots`: Assigned exam times (with `sent_to_student` lock flag)
- `exam_slot_histories`: Audit trail of slot changes
- `sections`: Course sections (lecture/lab)
- `students`: Student roster (name, email, cohort)
- `recordings`: Audio recordings of exams
- `system_configs`: Configuration key-value pairs
- `users`: Admin/TA accounts

### macOS App (Core Data)

Entities in `/clementime-mac/Clementime/Clementime/Clementime.xcdatamodeld`:
- `CourseEntity`: Top-level course container
- `ExamSessionEntity`: Exam configuration (date, time, duration)
- `CohortEntity`: Custom cohort definitions (unlimited, not just odd/even)
- `SectionEntity`: Course sections
- `StudentEntity`: Student roster with cohort assignment
- `ExamSlotEntity`: Scheduled exam times
- `ExamSlotHistoryEntity`: Audit trail
- `ConstraintEntity`: Time/date constraints
- `RecordingEntity`: Audio recordings (stored in iCloud)
- `TAUserEntity`: TA accounts with granular permissions (8 permission types)

**CloudKit Sync**: All entities sync automatically to iCloud when user is signed in.

## Key Technology Differences

| Aspect | Web App | macOS App |
|--------|---------|-----------|
| **Language** | Ruby 3.4.6 + JavaScript | Swift 5.9+ |
| **Framework** | Rails 8.1.1 + React 19 | SwiftUI |
| **Database** | PostgreSQL + Redis | Core Data + CloudKit |
| **Offline Support** | ❌ No | ✅ Full offline-first |
| **Cohorts** | 2 fixed (odd/even) | ∞ unlimited custom |
| **Exam Limit** | 5 max | ∞ unlimited |
| **Permissions** | Basic (admin/TA) | Granular (8 permission types) |
| **Deployment** | Docker, Render.com | Mac App Store (planned) |
| **Integrations** | Slack, Canvas LMS | iCloud, CloudKit Share |

## Development Notes

### Web App

- **Rails 8 Omakase Stack**: Uses Solid Cache/Queue/Cable (not Sidekiq/Memcached)
- **Linting**: RuboCop with `rubocop-rails-omakase` (opinionated style)
- **Security**: Brakeman scanner for vulnerabilities (runs in CI)
- **CORS**: Configured via `rack-cors` gem
- **File Storage**: Supports Google Drive OR Cloudflare R2 (S3-compatible)
- **Authentication**: BCrypt password hashing, JWT tokens for API
- **Docker**: Multi-stage builds for production deployment

### macOS App

- **Clean Architecture**: Strict separation of presentation/domain/data layers
- **SwiftLint**: Comprehensive rules in `.swiftlint.yml` (30+ opt-in rules)
- **Async/Await**: Modern concurrency throughout (no completion handlers)
- **CloudKit Sharing**: Courses can be shared with TAs via CloudKit Share
- **Export/Import**: `.clementime` files for course backup/transfer
- **Audio Recording**: AVFoundation for built-in recording, stored in iCloud
- **PDF Export**: Schedule export via SwiftUI rendering

### CI/CD (GitHub Actions)

**`.github/workflows/ci.yml`**:
- Brakeman security scan (Rails)
- RuboCop linting (Rails)
- ESLint + Prettier (React client + landing page)

**`.github/workflows/swift-lint.yml`**:
- SwiftLint checks for macOS app

**`.github/workflows/release.yml`**:
- Triggered by version tags (e.g., `v25.2.0`)
- Builds Docker image for web app
- Builds macOS DMG installer
- Creates GitHub release with changelog
- Pushes to Docker Hub

## Testing

### Web App

```bash
# Run all tests
make test                              # Via Docker
bundle exec rails test                 # Direct (requires local setup)

# Test a single file
bundle exec rails test test/models/student_test.rb

# Test with coverage (if configured)
COVERAGE=true bundle exec rails test
```

### macOS App

```bash
# Run all tests in Xcode
⌘U (Cmd+U)

# Command-line tests
xcodebuild test -scheme Clementime -destination 'platform=macOS'

# Test a specific test case
xcodebuild test -scheme Clementime -only-testing:ClementimeTests/ScheduleGeneratorTests
```

## Important File Locations

### Web App
- **Routes**: `/clementime-web/config/routes.rb`
- **Schema**: `/clementime-web/db/schema.rb`
- **Environment**: `/clementime-web/.env` (create from `.env.example`)
- **Docker Compose**: `/clementime-web/docker-compose.yml` (dev), `docker-compose.production.yml` (prod)
- **Frontend Config**: `/clementime-web/client/vite.config.js`, `tailwind.config.cjs`

### macOS App
- **Xcode Project**: `/clementime-mac/Clementime/Clementime.xcodeproj`
- **Core Data Model**: `/clementime-mac/Clementime/Clementime/Clementime.xcdatamodeld`
- **Entitlements**: `/clementime-mac/Clementime/Clementime/Clementime.entitlements` (iCloud permissions)
- **SwiftLint Config**: `/clementime-mac/.swiftlint.yml`
- **Info.plist**: `/clementime-mac/Clementime/Clementime/Info.plist`

### Shared
- **Main README**: `/README.md` (project overview)
- **Release Script**: `/scripts/release.sh`
- **Version File**: `/VERSION` (single source of truth for version number)
- **Deployment Docs**: `/docs/DEPLOYMENT_GUIDE.md`, `/docs/QUICK_START.md`

## CSV Roster Import Format

Both platforms support CSV roster imports with this exact format:

```csv
sis_user_id,email,full_name,section_code
student001,alice@stanford.edu,Alice Johnson,F25-PSYCH-10-01
student002,bob@stanford.edu,Bob Smith,F25-PSYCH-10-02
```

**Required columns**:
- `sis_user_id`: Student's unique ID from SIS
- `email`: Student's email address
- `full_name`: Student's full name
- `section_code`: Section identifier matching your course

Example files: `/docs/examples/roster-mac-example.csv`, `/docs/examples/roster-web-example.csv`

## Deployment

### Web App Deployment

**Quick Deploy to Render.com**:
```bash
cd clementime-web
make deploy-render MSG="Deploy message"  # Pushes to GitHub, Render auto-deploys
```

**Docker Deployment**:
```bash
cd clementime-web
make build                               # Build image
make push                                # Push to Docker Hub
docker pull shawnschwartz/clementime:latest
docker-compose -f docker-compose.production.yml up -d
```

**Environment Variables Required**:
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `SECRET_KEY_BASE`: Rails secret (generate with `rails secret`)
- `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET`: Slack OAuth
- `CANVAS_API_KEY`, `CANVAS_BASE_URL`: Canvas LMS integration
- `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`: Cloudflare R2 storage

### macOS App Distribution

**Local Build**:
1. Open `Clementime.xcodeproj` in Xcode
2. Select "Any Mac" as build destination
3. Product → Archive
4. Distribute App → Developer ID (for distribution outside Mac App Store)

**Automated Build** (via release script):
```bash
./scripts/release.sh        # Creates DMG in GitHub release
```

## Project Status

**Web App**: Production-ready, maintenance mode
- Used in production at universities
- Receives bug fixes and security updates
- No major new features planned

**macOS App**: Active development
- Core features implemented
- Planned features: Slack integration, Canvas LMS integration
- Target: Mac App Store distribution

**Landing Page** (`/landing`): Static marketing site (separate Node.js project)

## When Making Changes

### Web App Changes
1. **Database Changes**: Always create migrations (`rails g migration`)
2. **API Changes**: Update both controller AND client API service files
3. **Lint Before Commit**: Run `make lint-fix` to auto-fix style issues
4. **Security**: Run `bundle exec brakeman` to check for vulnerabilities
5. **Environment Variables**: Add new vars to `.env.example` with documentation

### macOS App Changes
1. **Core Data Changes**: Always create new model version (do NOT edit existing)
2. **Repository Pattern**: Changes to data layer should go through repositories
3. **Dependency Injection**: Register new dependencies in `DependencyContainer.swift`
4. **SwiftLint**: Run `swiftlint` before committing (enforced in CI)
5. **CloudKit**: Changes to synced entities require CloudKit schema updates

## Useful Patterns

### Web App: Adding a New API Endpoint
1. Define route in `config/routes.rb`
2. Create controller action in `app/controllers/api/admin/*_controller.rb`
3. Extract business logic to service in `app/services/*_service.rb`
4. Add client method in `client/src/services/*Service.js`
5. Call from React component

### macOS App: Adding a New Feature
1. Define domain entity in `Core/Domain/Entities/`
2. Create repository protocol in `Core/Domain/Repositories/`
3. Implement repository in `Data/Repositories/`
4. Create use case in `Core/Domain/UseCases/`
5. Create ViewModel in `ViewModels/`
6. Create SwiftUI View in `Views/`
7. Register dependencies in `DependencyContainer.swift`

## Common Gotchas

- **Web App**: Don't use Sidekiq or Memcached (Rails 8 uses Solid Queue/Cache instead)
- **Web App**: CORS must be configured in `config/initializers/cors.rb` for React client
- **macOS App**: Always use async/await, never `@MainActor` on repository methods
- **macOS App**: Core Data entities are NOT domain entities (use mappers)
- **Both**: The scheduling algorithm must remain identical between platforms
- **Both**: Cohort assignment logic differs (fixed odd/even vs unlimited custom)
