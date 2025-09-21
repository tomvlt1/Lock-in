# Habit Tracker iOS App

A single-user habit-tracking iPhone app with zero cloud syncing—all data remains on-device. Built with SwiftUI and SwiftData for iOS 17+.

## Features

### Core Functionality
- **Morning & Evening Reminders**: Local notifications at customizable times (default 07:30 & 21:30)
- **Quick Checklist**: Notification tap opens a sheet showing today's tasks with one-tap ✓/✗ completion
- **Recovery Mode**: Missed reminder recovery banner on next launch ("Log last night's tasks?")

### Dashboard & Analytics
- **Line Chart**: Daily completion rate (0–100%) with 7-day moving average using Swift Charts
- **Heat Map**: 30-day colored visualization (green = all done, yellow = partial, red = zero)
- **Analytics**: "Most-skipped tasks" list sorted by skip rate

### Task Management
- Add, edit, and archive tasks
- Archive hides tasks but preserves historical completions
- Swipe actions for quick management

### Technical Highlights
- **SwiftData**: Modern data persistence (iOS 17+)
- **Local-only Storage**: No iCloud, all data in app sandbox
- **MVVM Architecture**: Observable pattern with SwiftUI
- **Live Activity Support**: Ready for Dynamic Island integration (TODO)
- **Unit Test Ready**: Includes test helpers and sample data

## Build & Run Instructions

### Prerequisites
- Xcode 16 or later
- iOS 18 SDK (or latest stable)
- Apple Developer account (for 7-day free provisioning)

### Setup Steps

1. **Create New Project**
   ```
   Follow instructions in ProjectSetup.md
   ```

2. **Add Files to Xcode Project**
   - Copy all `.swift` files to your project
   - Ensure proper group organization (see ProjectSetup.md)

3. **Configure Capabilities**
   - Enable "Background Modes" → "Background App Refresh"
   - Add notification usage description to Info.plist:
   ```xml
   <key>NSUserNotificationUsageDescription</key>
   <string>This app needs notification permissions to remind you about your daily habits.</string>
   ```

4. **Bundle ID Configuration**
   - Use format: `com.yourname.habittracker`
   - Enable automatic signing with your Apple ID
   - Minimum iOS version: 17.0

5. **Build and Run**
   - Select your device/simulator
   - Build (⌘+B) and Run (⌘+R)

### First Launch
- Grant notification permissions when prompted
- Add your first habits in Settings
- Test notifications by setting reminder times a few minutes ahead

## Architecture Overview

```
App Structure:
├── Models (SwiftData)
│   ├── Task.swift - Habit definition and completion logic
│   ├── Completion.swift - Individual completion records
│   └── AppSettings.swift - User preferences
├── ViewModels
│   └── TaskViewModel.swift - Data management and business logic
├── Views
│   ├── DashboardView.swift - Main screen with charts
│   ├── ChecklistSheetView.swift - Quick completion interface
│   └── SettingsView.swift - Configuration and task management
├── Services
│   └── NotificationManager.swift - Local notification handling
└── Utilities
    └── SampleData.swift - Test data and preview helpers
```

## Testing

### Manual Testing
1. Add several habits
2. Set notification times 1-2 minutes in the future
3. Test notification tap → checklist opens
4. Test recovery banner by missing a notification
5. Verify charts update after logging completions

### Unit Testing
The app includes comprehensive test helpers:
```swift
// Create test data
let (tasks, settings) = SampleData.createMinimalTestData(in: context)

// Test streak calculation
let streakTask = SampleData.createStreakTestData(in: context)
let rate = streakTask.completionRate(for: 7)
```

## Future Nice-to-Haves

### Upcoming Features
- **Shortcuts Integration**: Siri shortcuts for quick habit logging
- **CSV Export**: Export habit data for external analysis
- **Live Activities**: Dynamic Island integration for active checklists
- **Habit Streaks**: Visual streak counters and milestone celebrations
- **Custom Categories**: Group habits by morning/evening/health/productivity
- **Progress Photos**: Attach progress images to specific habits
- **Widget Support**: Home screen widgets for quick status view

### Performance Optimizations
- Batch completion updates for better performance
- Core Data migration path for iOS 16 support
- Background processing for analytics calculations

### Enhanced Analytics
- Monthly/yearly completion trends
- Habit correlation analysis (which habits are completed together)
- Personalized insights and suggestions
- Export to Apple Health integration

## Data Privacy

- **100% On-Device**: No data leaves your iPhone
- **No Analytics**: No usage tracking or telemetry
- **No Accounts**: No sign-up or login required
- **Sandbox Storage**: All data stored in app's private directory
- **Manual Backup**: Data included in iTunes/Finder backups only

## Troubleshooting

### Notifications Not Working
1. Check Settings → Notifications → HabitTracker
2. Ensure "Allow Notifications" is enabled
3. Verify notification times in app settings
4. Try setting a test notification 2 minutes ahead

### Data Not Persisting
1. Ensure iOS 17+ (SwiftData requirement)
2. Check device storage (low space can prevent saves)
3. Restart app if data appears corrupted

### Performance Issues
1. Archive old unused habits
2. The app maintains 30 days of completion data by default
3. Restart if analytics become slow to load

## License

This code is provided as-is for educational purposes. Feel free to modify and distribute according to your needs.

## Support

For technical support or feature requests, please refer to the inline TODO comments in the source code for guidance on implementation.