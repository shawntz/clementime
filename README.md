# ClemenTime

A comprehensive exam scheduling and management system for oral exams.

## Project Structure

This repository contains two versions of ClemenTime:

### 📱 [clementime-mac](./clementime-mac)
**Native macOS Application** (Swift + SwiftUI + CloudKit)

- Modern native Mac app built with SwiftUI
- iCloud sync with CloudKit
- Offline-first architecture with Core Data
- Flexible course structure with unlimited cohorts
- Custom TA permissions system
- Audio recording with iCloud storage
- **Status**: Active development

**Requirements**: macOS 14.0+

[Read Mac App Documentation →](./clementime-mac/README.md)

### 🌐 [clementime-web](./clementime-web)
**Web Application** (Rails + React)

- Full-featured web application
- PostgreSQL database
- Google Drive integration
- Slack notifications
- Canvas LMS integration
- **Status**: Legacy / maintenance mode

**Requirements**: Ruby 3.4.6+, Rails 8.1.1+, PostgreSQL, Node.js

[Read Web App Documentation →](./clementime-web/README.md)

## Migration Path

The Mac app is a complete rewrite with enhanced features:

- ✅ No external backend dependencies (was: Rails + PostgreSQL)
- ✅ iCloud sync (was: Google Drive + manual setup)
- ✅ Unlimited custom cohorts (was: fixed odd/even weeks)
- ✅ Flexible exam sessions (was: limited to 5 exams)
- ✅ Custom TA permissions (was: basic admin/TA roles)
- ✅ Native performance and offline support

## Quick Start

### Mac App (Recommended)

```bash
cd clementime-mac
open ClemenTime.xcodeproj
```

Follow the [Mac App Setup Guide](./clementime-mac/CORE_DATA_MODEL_SETUP.md).

### Web App (Legacy)

```bash
cd clementime-web
bin/setup
bin/dev
```

## Features Comparison

| Feature | Mac App | Web App |
|---------|---------|---------|
| Platform | macOS 14+ | Web (any browser) |
| Backend | iCloud (CloudKit) | Rails + PostgreSQL |
| Offline Support | ✅ Full | ❌ No |
| Cohorts | ∞ Unlimited | 2 (odd/even) |
| Exam Limit | ∞ Unlimited | 5 exams |
| Permissions | Granular (8 types) | Basic (admin/TA) |
| Audio Recording | ✅ Built-in | ✅ Via browser |
| File Storage | iCloud | Google Drive / R2 |
| Slack Integration | 🚧 Planned | ✅ Yes |
| Canvas Integration | 🚧 Planned | ✅ Yes |
| Share Courses | ✅ CloudKit Share | ❌ No |
| Real-time Sync | ✅ Automatic | ❌ Manual refresh |

## Architecture

### Mac App Architecture

```
SwiftUI Views + ViewModels (Presentation)
    ↓
Use Cases + Entities (Domain)
    ↓
Repositories + Core Data (Data)
    ↓
CloudKit + AVFoundation (Infrastructure)
```

### Web App Architecture

```
React Components (Frontend)
    ↓
Rails API (Backend)
    ↓
PostgreSQL + Redis (Storage)
    ↓
Google Drive + Slack (Integrations)
```

## Development Timeline

### Phase 1: Foundation ✅
- [x] Reorganize repository structure
- [x] Create Xcode project
- [x] Implement domain entities
- [x] Set up Core Data model
- [ ] Configure CloudKit capabilities

### Phase 2: Core Functionality (Current)
- [ ] Implement repositories
- [ ] Port schedule generation algorithm
- [ ] Build constraint checking
- [ ] Add history tracking

### Phase 3: UI
- [ ] Main app structure
- [ ] Course builder with cohorts
- [ ] Schedule view with generation
- [ ] Student management with import

### Phase 4: Sharing & Permissions
- [ ] CloudKit sharing
- [ ] Permission system
- [ ] TA invitation flow
- [ ] Permission UI gates

### Phase 5: Recording
- [ ] Audio recording
- [ ] iCloud upload/download
- [ ] Recording UI
- [ ] Playback

### Phase 6: Polish
- [ ] CSV export
- [ ] Settings
- [ ] Error handling
- [ ] Testing
- [ ] App Store submission

## Contributing

This is a personal project for managing oral exam schedules. Contributions and suggestions are welcome!

## License

[Add your license here]

## Contact

For questions or support:
- Open an issue on GitHub
- [Your contact information]

---

**Note**: The web app (clementime-web) is in maintenance mode. All new features are being developed for the Mac app (clementime-mac).
