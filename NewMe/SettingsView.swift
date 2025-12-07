import SwiftUI
import UIKit
import EventKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var notificationManager: NotificationManager
    
    @State private var morningTime: Date = Date()
    @State private var eveningTime: Date = Date()
    @State private var notificationsEnabled: Bool = true
    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    @State private var showingArchived = false
    @State private var showingEditTaskSheet = false
    @State private var editingTaskTitle = ""
    @State private var taskBeingEdited: Task?
    @State private var taskToDelete: Task?
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var csvContent = ""
    @State private var calendarSyncEnabled = false

    // Import
    @State private var showingImportPicker = false
    @State private var lastImportResult: String?

    var body: some View {
        NavigationView {
            List {
                notificationSection
                calendarSection
                habitManagementSection
                if !viewModel.archivedTasks.isEmpty {
                    archivedTasksSection
                }
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTask, content: {
            AddTaskSheetWithPeriods(newTaskTitle: $newTaskTitle) { periods, category, weight in
                if !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.addTask(
                        title: newTaskTitle,
                        periods: periods,
                        category: category,
                        weight: weight
                    )
                    newTaskTitle = ""
                }
                showingAddTask = false
            }
        })
        .sheet(isPresented: $showingArchived, content: {
            ArchivedTasksView()
        })
        .sheet(isPresented: $showingEditTaskSheet, content: {
            if let task = taskBeingEdited {
                EditTaskView(
                    taskTitle: $editingTaskTitle,
                    originalTitle: task.title ?? "Untitled Task",
                    task: task
                ) { periods, category, weight in
                    if !editingTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.updateTask(
                            task,
                            title: editingTaskTitle,
                            periods: periods,
                            category: category,
                            weight: weight
                        )
                    }
                    taskBeingEdited = nil
                    showingEditTaskSheet = false
                }
            }
        })
        .onAppear {
            loadCurrentSettings()
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Habit"),
                message: Text("Are you sure you want to permanently delete \"\(taskToDelete?.title ?? "this habit")\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let task = taskToDelete {
                        viewModel.deleteTask(task)
                    }
                    taskToDelete = nil
                },
                secondaryButton: .cancel {
                    taskToDelete = nil
                }
            )
        }
        .sheet(isPresented: $showingShareSheet, content: {
            ActivityViewController(
                activityItems: [createCSVFile()],
                excludedActivityTypes: [.assignToContact, .addToReadingList]
            )
        })
        // CSV Import picker with copy-to-temp to avoid security scope issues
        .sheet(isPresented: $showingImportPicker, content: {
            DocumentPicker { url in
                guard let pickedURL = url else { return }
                DispatchQueue.global(qos: .userInitiated).async {
                    // Copy to a temp URL inside our container to avoid provider/scope issues
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
                    do {
                        // Remove if exists
                        if FileManager.default.fileExists(atPath: tempURL.path) {
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                        try FileManager.default.copyItem(at: pickedURL, to: tempURL)
                        let result = try viewModel.importFromCSV(url: tempURL)
                        DispatchQueue.main.async {
                            lastImportResult = "Import finished: \(result)"
                        }
                    } catch {
                        // If copy fails, try importing directly as fallback
                        do {
                            let result = try viewModel.importFromCSV(url: pickedURL)
                            DispatchQueue.main.async {
                                lastImportResult = "Import finished: \(result)"
                            }
                        } catch {
                            DispatchQueue.main.async {
                                lastImportResult = "Import failed: \(friendlyImportError(error))"
                            }
                        }
                    }
                }
            }
        })
    }
    
    // MARK: - Notification Settings
    
    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Daily Reminders", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { newValue in
                    viewModel.toggleNotifications(newValue)
                }
            
            if notificationsEnabled {
                HStack {
                    Label("Morning Reminder", systemImage: "sunrise")
                    Spacer()
                    DatePicker("", selection: $morningTime, displayedComponents: .hourAndMinute)
                        .onChange(of: morningTime) { _ in
                            updateNotificationTimes()
                        }
                }
                
                HStack {
                    Label("Evening Reminder", systemImage: "moon")
                    Spacer()
                    DatePicker("", selection: $eveningTime, displayedComponents: .hourAndMinute)
                        .onChange(of: eveningTime) { _ in
                            updateNotificationTimes()
                        }
                }
            }
            
            HStack {
                Text("Permission Status")
                Spacer()
                Text(permissionStatusText)
                    .foregroundColor(permissionStatusColor)
                    .font(.caption)
            }
        }
    }

    // MARK: - Calendar Integration

    private var calendarSection: some View {
        Section("Calendar Integration") {
            Toggle("Sync notes to calendar", isOn: $calendarSyncEnabled)
                .onChange(of: calendarSyncEnabled) { enabled in
                    handleCalendarToggleChange(enabled)
                }

            HStack {
                Text("Calendar Permission")
                Spacer()
                Text(calendarPermissionStatusText)
                    .foregroundColor(calendarPermissionStatusColor)
                    .font(.caption)
            }

            if calendarPermissionStatus == .denied {
                Button("Open Settings") {
                    openAppSettings()
                }
                .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Habit Management
    
    private var habitManagementSection: some View {
        Section("Habit Management") {
            Button {
                showingAddTask = true
            } label: {
                Label("Add New Habit", systemImage: "plus.circle")
            }
            
            ForEach(sortedActiveTasks, id: \.id) { task in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title ?? "Untitled Task")
                            .font(.body)
                        Text("\(task.categoryEnum.displayName) • \(task.weightEnum.displayName) weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
                .contextMenu {
                    Button("Edit") {
                        taskBeingEdited = task
                        editingTaskTitle = task.title ?? "Untitled Task"
                        showingEditTaskSheet = true
                    }
                    Button("Archive") {
                        viewModel.archiveTask(task)
                    }
                    Divider()
                    Button("Delete") {
                        taskToDelete = task
                        showingDeleteAlert = true
                    }
                }
            }
        }
    }
    
    // MARK: - Archived Tasks (inline section)
    
    private var archivedTasksSection: some View {
        Section("Archived Habits") {
            ForEach(viewModel.archivedTasks, id: \.id) { task in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title ?? "Untitled Task")
                            .font(.body)
                        Text("Archived \(task.created ?? Date(), style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
                .contextMenu {
                    Button("Restore") {
                        viewModel.unarchiveTask(task)
                    }
                    Divider()
                    Button("Delete Permanently") {
                        taskToDelete = task
                        showingDeleteAlert = true
                    }
                }
            }
            
            Button {
                showingArchived = true
            } label: {
                Label("Manage Archived...", systemImage: "tray.full")
            }
        }
    }
    
    // MARK: - Data Section (Export/Import)
    
    private var dataSection: some View {
        Section("Data & Export") {
            Button {
                exportToCSV()
            } label: {
                HStack {
                    Label("Export Task History", systemImage: "square.and.arrow.up")
                    Spacer()
                }
            }
            .foregroundColor(.primary)

            Button {
                showingImportPicker = true
            } label: {
                HStack {
                    Label("Import from CSV", systemImage: "square.and.arrow.down")
                    Spacer()
                }
            }
            .foregroundColor(.primary)

            if let lastImportResult = lastImportResult {
                Text(lastImportResult)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Data Storage")
                Spacer()
                VStack(alignment: .trailing) {
                    Text("On-Device Only")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("No Cloud Sync")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                }
            }
        }
    }
    
    // MARK: - About Section

    private var aboutSection: some View {
        Group {
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://apple.com/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties

    private var sortedActiveTasks: [Task] {
        let today = Calendar.current.startOfDay(for: Date())
        return viewModel.activeTasks.sorted { first, second in
            let firstComplete = first.isFullyCompleted(on: today)
            let secondComplete = second.isFullyCompleted(on: today)
            if firstComplete == secondComplete {
                return (first.title ?? "").localizedCaseInsensitiveCompare(second.title ?? "") == .orderedAscending
            }
            return !firstComplete && secondComplete
        }
    }
    
    private var permissionStatusText: String {
        switch notificationManager.permissionStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Set"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var permissionStatusColor: Color {
        switch notificationManager.permissionStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .ephemeral:
            return .blue
        @unknown default:
            return .gray
        }
    }

    // MARK: - Calendar Helper Properties

    private var calendarPermissionStatus: EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }

    private var calendarPermissionStatusText: String {
        switch calendarPermissionStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Set"
        case .restricted:
            return "Restricted"
        @unknown default:
            return "Unknown"
        }
    }

    private var calendarPermissionStatusColor: Color {
        switch calendarPermissionStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }

    // MARK: - Helper Functions
    
    private func loadCurrentSettings() {
        guard let settings = viewModel.settings else { return }
        morningTime = settings.morningReminderTime ?? Period.morning.defaultTime
        eveningTime = settings.eveningReminderTime ?? Period.evening.defaultTime
        notificationsEnabled = settings.notificationsEnabled
        calendarSyncEnabled = settings.calendarSyncEnabled
    }
    
    private func updateNotificationTimes() {
        viewModel.updateNotificationTimes(morning: morningTime, evening: eveningTime)
    }

    private func exportToCSV() {
        csvContent = viewModel.exportTaskHistoryToCSV()
        if !csvContent.isEmpty {
            showingShareSheet = true
        }
    }

    private func createCSVFile() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "habit-history-\(dateFormatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let contentToWrite = csvContent.isEmpty ? "Date,Task,Period,Completed,Weight\nNo data available,,,,\n" : csvContent
        try? contentToWrite.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    private func handleCalendarToggleChange(_ enabled: Bool) {
        if enabled {
            switch calendarPermissionStatus {
            case .authorized:
                viewModel.updateCalendarSyncPreference(true)
            case .notDetermined:
                requestCalendarPermission { granted in
                    calendarSyncEnabled = granted
                    viewModel.updateCalendarSyncPreference(granted)
                }
            case .denied, .restricted:
                calendarSyncEnabled = false
                viewModel.updateCalendarSyncPreference(false)
            @unknown default:
                calendarSyncEnabled = false
                viewModel.updateCalendarSyncPreference(false)
            }
        } else {
            viewModel.updateCalendarSyncPreference(false)
        }
    }

    private func requestCalendarPermission(completion: ((Bool) -> Void)? = nil) {
        CalendarManager.shared.requestCalendarAccess { granted in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    // MARK: - Friendly CSV error mapping

    private func friendlyImportError(_ error: Error) -> String {
        if let csvError = error as? TaskViewModel.CSVImportError {
            switch csvError {
            case .invalidFile:
                return "The selected file could not be accessed."
            case .unreadableData:
                return "The file could not be read (encoding/permissions)."
            case .malformedHeader:
                return "The header row is not in a recognized format."
            case .malformedRow:
                return "One of the rows is malformed."
            case .dateParseFailed(let s):
                return "Date format not recognized: \(s). Expected yyyy-MM-dd, M/d/yy, or M/d/yyyy."
            }
        }
        return error.localizedDescription
    }
}

struct AddTaskSheetWithPeriods: View {
    @Binding var newTaskTitle: String
    let onSave: (Set<Period>, TaskCategory, TaskWeight) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPeriods: Set<Period> = [.morning, .evening]
    @State private var selectedCategory: TaskCategory = .general
    @State private var selectedWeight: TaskWeight = .low
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add New Habit")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Habit Name")
                        .font(.headline)
                    TextField("e.g., Drink 8 glasses of water", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("When do you want to track this habit?")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        PeriodSelectionRowSimple(
                            title: "Morning",
                            subtitle: "Track this habit in the morning",
                            period: .morning,
                            selectedPeriods: $selectedPeriods
                        )
                        PeriodSelectionRowSimple(
                            title: "Evening",
                            subtitle: "Track this habit in the evening",
                            period: .evening,
                            selectedPeriods: $selectedPeriods
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(.headline)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TaskCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weight")
                        .font(.headline)
                    
                    Picker("Weight", selection: $selectedWeight) {
                        ForEach(TaskWeight.allCases) { weight in
                            Text(weight.displayName).tag(weight)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onSave(selectedPeriods, selectedCategory, selectedWeight)
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedPeriods.isEmpty)
                }
            }
        }
    }
}

struct PeriodSelectionRowSimple: View {
    let title: String
    let subtitle: String
    let period: Period
    @Binding var selectedPeriods: Set<Period>
    
    private var isSelected: Bool {
        selectedPeriods.contains(period)
    }
    
    var body: some View {
        Button {
            if isSelected {
                selectedPeriods.remove(period)
            } else {
                selectedPeriods.insert(period)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ArchivedTasksView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var taskToDelete: Task?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.archivedTasks.isEmpty {
                    Text("No archived habits")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(viewModel.archivedTasks, id: \.id) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title ?? "Untitled Task")
                                    .font(.body)
                                Text("Archived \(task.created ?? Date(), style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.gray)
                        }
                        .contextMenu {
                            Button("Restore") {
                                viewModel.unarchiveTask(task)
                            }
                            Divider()
                            Button("Delete Permanently") {
                                taskToDelete = task
                                showingDeleteAlert = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Archived Habits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Permanently"),
                message: Text("Are you sure you want to permanently delete \"\(taskToDelete?.title ?? "this habit")\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let task = taskToDelete {
                        viewModel.deleteTask(task)
                    }
                    taskToDelete = nil
                },
                secondaryButton: .cancel {
                    taskToDelete = nil
                }
            )
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?

    init(activityItems: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) {
        self.activityItems = activityItems
        self.excludedActivityTypes = excludedActivityTypes
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        activityViewController.excludedActivityTypes = excludedActivityTypes
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText, .text, .data], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) {
            self.onPick = onPick
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(TaskViewModel.createPreviewViewModel())
            .environmentObject(NotificationManager.shared)
    }
}
