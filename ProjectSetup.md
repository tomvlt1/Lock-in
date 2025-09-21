# ProjectSetup.md

## Xcode Project Creation Steps

1. **Create New Project**
   - Open Xcode 16
   - Create new iOS app project
   - Choose "iOS" platform
   - Select "App" template

2. **Project Configuration**
   - Product Name: `HabitTracker`
   - Interface: SwiftUI
   - Language: Swift
   - Use Core Data: ❌ (we'll use SwiftData)
   - Include Tests: ✅

3. **Bundle ID Configuration**
   - Use reverse domain notation: `com.yourname.habittracker`
   - For 7-day free provisioning, ensure you're signed in with your Apple ID
   - Select "Automatically manage signing"
   - Choose your development team

4. **Required Capabilities**
   - Background Modes: Local notifications
   - Do NOT enable CloudKit or iCloud capabilities

5. **Target Settings**
   - Minimum iOS Version: 17.0 (for SwiftData)
   - Supported orientations: Portrait only

6. **Info.plist Additions**
   ```xml
   <key>NSUserNotificationUsageDescription</key>
   <string>This app needs notification permissions to remind you about your daily habits.</string>
   ```

## Project Structure
```
HabitTracker/
├── App/
│   ├── HabitTrackerApp.swift
│   └── ContentView.swift
├── Models/
│   └── DataModels.swift
├── ViewModels/
│   └── TaskViewModel.swift
├── Views/
│   ├── DashboardView.swift
│   ├── ChecklistSheetView.swift
│   └── SettingsView.swift
├── Services/
│   └── NotificationManager.swift
└── Utilities/
    └── SampleData.swift
```