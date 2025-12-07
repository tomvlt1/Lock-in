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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    todaySummarySection
                    chartSection
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
                        Image(systemName: "plus")
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
    
    private var todaySummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Plank")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.plankEntries.isEmpty && todaysTotal == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "figure.core.training")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("No plank logged today")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add your plank duration in seconds to keep track of your progress.")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundColor(.secondary)
                    Button("Log Plank") {
                        showingAddEntry = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(todaysTotal)) sec")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Logged today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        let weeklyTotal = viewModel.getDailyPlankTotals(forLast: 7).reduce(0) { $0 + $1.seconds }
                        Text("\(Int(weeklyTotal)) sec")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Last 7 days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Progress")
                .font(.title2)
                .fontWeight(.bold)
            
            let data = viewModel.getDailyPlankTotals(forLast: 14)
            if data.allSatisfy({ $0.seconds == 0 }) {
                Text("Log plank time to see your weekly chart.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
            } else {
                PlankBarChart(data: data)
                    .frame(height: 220)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Entries")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.plankEntries.isEmpty {
                Text("No entries yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.plankEntries.prefix(10), id: \.id) { entry in
                        PlankEntryRow(entry: entry) {
                            viewModel.deletePlankEntry(entry)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Components

private struct PlankEntryRow: View {
    let entry: PlankEntry
    let onDelete: () -> Void
    
    private var formattedDate: String {
        guard let date = entry.date else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.body)
                Text("\(Int(entry.durationSeconds)) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

private struct PlankBarChart: View {
    let data: [(date: Date, seconds: Double)]
    
    private var maxValue: Double {
        data.map { $0.seconds }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.date) { entry in
                    VStack(spacing: 4) {
                        Text("\(Int(entry.seconds))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.8))
                            .frame(height: barHeight(for: entry.seconds))
                        Text(shortDate(entry.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    private func barHeight(for value: Double) -> CGFloat {
        guard maxValue > 0 else { return 10 }
        let normalized = value / maxValue
        return max(10, normalized * 160)
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

private struct AddPlankEntryView: View {
    @Binding var durationText: String
    @Binding var selectedDate: Date
    let onSave: () -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Duration (seconds)")) {
                    TextField("e.g. 60", text: $durationText)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Date")) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Log Plank")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(Double(durationText) ?? 0 <= 0)
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
