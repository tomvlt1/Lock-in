import SwiftUI

struct PlankTrackingView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var showingAddEntry = false
    @State private var durationText = ""
    @State private var selectedDate = Date()
    
    private var todaysTotal: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.plankEntries.reduce(0) { total, entry in
            guard let date = entry.date else { return total }
            return calendar.isDate(date, inSameDayAs: today) ? total + entry.durationSeconds : total
        }
    }
    
    private var weeklyTotal: Double {
        viewModel.getDailyPlankTotals(forLast: 7).reduce(0) { $0 + $1.seconds }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Stats
                    statsCardsSection
                    
                    // Chart
                    chartSection
                    
                    // Recent Entries
                    recentEntriesSection
                }
                .padding()
            }
            .navigationTitle("Plank Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEntry = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddPlankEntryView(durationText: $durationText, selectedDate: $selectedDate) {
                if let duration = Double(durationText), duration > 0 {
                    viewModel.addPlankEntry(durationSeconds: duration, date: selectedDate)
                    durationText = ""
                    selectedDate = Date()
                }
                showingAddEntry = false
            }
        }
    }
    
    // MARK: - Stats Cards
    
    private var statsCardsSection: some View {
        VStack(spacing: 12) {
            if todaysTotal == 0 {
                // Empty state with CTA
                VStack(spacing: 16) {
                    Image(systemName: "figure.core.training")
                        .font(.system(size: 56))
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                    
                    VStack(spacing: 6) {
                        Text("No Plank Today")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Start your core workout!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        showingAddEntry = true
                    } label: {
                        Text("Log Plank")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            } else {
                // Stats grid when data exists
                HStack(spacing: 12) {
                    StatCard(
                        title: "Today",
                        value: formatDuration(todaysTotal),
                        subtitle: "Total time",
                        color: .orange,
                        icon: "flame.fill"
                    )
                    
                    StatCard(
                        title: "Week",
                        value: formatDuration(weeklyTotal),
                        subtitle: "Last 7 days",
                        color: .blue,
                        icon: "chart.bar.fill"
                    )
                }
            }
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("Last 14 Days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            let data = viewModel.getDailyPlankTotals(forLast: 14)
            if data.allSatisfy({ $0.seconds == 0 }) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No data yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            } else {
                PlankBarChart(data: data)
                    .frame(height: 200)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Recent Entries
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                if !viewModel.plankEntries.isEmpty {
                    Text("\(viewModel.plankEntries.count) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.plankEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No entries yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            } else {
                VStack(spacing: 1) {
                    ForEach(Array(viewModel.plankEntries.prefix(15).enumerated()), id: \.element.id) { index, entry in
                        PlankEntryRow(entry: entry) {
                            viewModel.deletePlankEntry(entry)
                        }
                        
                        if index < min(14, viewModel.plankEntries.count - 1) {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Stat Card Component

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Plank Entry Row

private struct PlankEntryRow: View {
    let entry: PlankEntry
    let onDelete: () -> Void
    
    private var formattedDate: String {
        guard let date = entry.date else { return "Unknown date" }
        let formatter = DateFormatter()
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private var formattedDuration: String {
        let totalSeconds = Int(entry.durationSeconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        
        if minutes > 0 {
            return "\(minutes) min \(secs) sec"
        } else {
            return "\(secs) seconds"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "figure.core.training")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.body)
                    .fontWeight(.medium)
                Text(formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Delete button
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Bar Chart

private struct PlankBarChart: View {
    let data: [(date: Date, seconds: Double)]
    
    private var maxValue: Double {
        data.map { $0.seconds }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chart
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(data, id: \.date) { entry in
                    VStack(spacing: 6) {
                        // Value label
                        if entry.seconds > 0 {
                            Text(shortDuration(entry.seconds))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        } else {
                            Text(" ")
                                .font(.caption2)
                        }
                        
                        // Bar
                        ZStack(alignment: .bottom) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 120)
                            
                            // Actual value
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: barHeight(for: entry.seconds))
                        }
                        
                        // Date label
                        Text(shortDate(entry.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func barHeight(for value: Double) -> CGFloat {
        guard maxValue > 0 else { return 4 }
        let normalized = value / maxValue
        return max(4, normalized * 115)
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func shortDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Add Entry Sheet

private struct AddPlankEntryView: View {
    @Binding var durationText: String
    @Binding var selectedDate: Date
    let onSave: () -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    // Quick time buttons (in seconds)
    private let quickTimes = [30, 60, 90, 120, 180]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "figure.core.training")
                            .font(.system(size: 56))
                            .foregroundColor(.orange)
                        Text("Log Plank Duration")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .padding(.top)
                    
                    // Quick time selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Select")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(quickTimes, id: \.self) { seconds in
                                Button {
                                    durationText = "\(seconds)"
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))")
                                            .font(.headline)
                                        Text("\(seconds)s")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        durationText == "\(seconds)" 
                                            ? Color.orange.opacity(0.2) 
                                            : Color(.secondarySystemGroupedBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                durationText == "\(seconds)" 
                                                    ? Color.orange 
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Custom duration input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Duration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("Enter seconds", text: $durationText)
                                .keyboardType(.numberPad)
                                .font(.title3)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            
                            Text("sec")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Date selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Save button
                    Button {
                        onSave()
                    } label: {
                        Text("Save Plank Entry")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                (Double(durationText) ?? 0) > 0 
                                    ? Color.orange 
                                    : Color.gray
                            )
                            .cornerRadius(12)
                    }
                    .disabled((Double(durationText) ?? 0) <= 0)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct PlankTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        PlankTrackingView()
            .environmentObject(TaskViewModel.createPreviewViewModel())
    }
}
