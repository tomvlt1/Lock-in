import SwiftUI
import Foundation

struct WeightTrackingView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var showingAddWeight = false
    @State private var newWeight = ""
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current weight section
                    currentWeightSection
                    
                    // Weight chart section
                    weightChartSection
                    
                    // Recent entries section
                    recentEntriesSection
                }
                .padding()
            }
            .navigationTitle("Weight Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddWeight = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddWeight) {
            AddWeightEntryView(newWeight: $newWeight, selectedDate: $selectedDate) {
                if let weight = Double(newWeight), weight > 0 {
                    viewModel.addWeightEntry(weight: weight, date: selectedDate)
                    newWeight = ""
                    selectedDate = Date()
                }
                showingAddWeight = false
            }
        }
    }
    
    // MARK: - Current Weight Section
    
    private var currentWeightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Weight")
                .font(.title2)
                .fontWeight(.bold)
            
            if let latestEntry = viewModel.weightEntries.first {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(latestEntry.weight, specifier: "%.1f") kg")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("Last updated: \(latestEntry.date ?? Date(), style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.weightEntries.count > 1 {
                        let previousEntry = viewModel.weightEntries[1]
                        let change = latestEntry.weight - previousEntry.weight
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                                .foregroundColor(change >= 0 ? .red : .green)
                            
                            Text("\(abs(change), specifier: "%.1f") kg")
                                .font(.caption)
                                .foregroundColor(change >= 0 ? .red : .green)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No weight entries yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add your first weight entry to start tracking your progress.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showingAddWeight = true
                    } label: {
                        Text("Add Weight Entry")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Weight Chart Section
    
    private var weightChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Chart")
                .font(.title2)
                .fontWeight(.bold)
            
            let chartData = viewModel.getWeightEntriesForChart()
            
            if chartData.count >= 2 {
                WeightLineChart(data: chartData)
                    .frame(height: 200)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            } else {
                Text("Add at least 2 weight entries to see your progress chart")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Recent Entries Section
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Entries")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.weightEntries.isEmpty {
                Text("No entries yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.weightEntries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                        WeightEntryRowView(entry: entry)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Weight Entry Row View

struct WeightEntryRowView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    let entry: WeightEntry
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.weight, specifier: "%.1f") kg")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(entry.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .contextMenu {
            Button("Delete") {
                showingDeleteAlert = true
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Weight Entry"),
                message: Text("Are you sure you want to delete this weight entry?"),
                primaryButton: .destructive(Text("Delete")) {
                    viewModel.deleteWeightEntry(entry)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Add Weight Entry View

struct AddWeightEntryView: View {
    @Binding var newWeight: String
    @Binding var selectedDate: Date
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Weight Entry")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your daily weight")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (kg)")
                            .font(.headline)
                        
                        TextField("e.g., 68.0", text: $newWeight)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                            .onSubmit {
                                onSave()
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.headline)
                        
                        DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
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
                        onSave()
                    }
                    .disabled(newWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(newWeight) == nil || Double(newWeight)! <= 0)
                }
            }
        }
    }
}

// MARK: - Weight Line Chart

struct WeightLineChart: View {
    let data: [(date: Date, weight: Double)]
    
    var body: some View {
        GeometryReader { geometry in
            let minWeight = data.map { $0.weight }.min() ?? 0
            let maxWeight = data.map { $0.weight }.max() ?? 0
            let weightRange = maxWeight - minWeight
            let adjustedMinWeight = weightRange > 0 ? minWeight - (weightRange * 0.1) : minWeight - 5
            let adjustedMaxWeight = weightRange > 0 ? maxWeight + (weightRange * 0.1) : maxWeight + 5
            let adjustedRange = adjustedMaxWeight - adjustedMinWeight
            
            let chartHeight = geometry.size.height - 60
            let chartWidth = geometry.size.width - 80
            
            ZStack {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<5) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 1)
                        Spacer()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                
                // Y-axis labels
                HStack {
                    VStack(spacing: 0) {
                        ForEach(0..<5) { index in
                            let value = adjustedMaxWeight - (Double(index) * adjustedRange / 4)
                            Text("\(value, specifier: "%.0f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if index < 4 { Spacer() }
                        }
                    }
                    .frame(width: 30)
                    
                    Spacer()
                }
                .padding(.vertical, 20)
                
                // Line chart path
                if data.count > 1 {
                    Path { path in
                        let points = data.enumerated().map { index, dataPoint in
                            CGPoint(
                                x: 40 + (CGFloat(index) / CGFloat(data.count - 1)) * chartWidth,
                                y: 20 + (adjustedMaxWeight - dataPoint.weight) / adjustedRange * chartHeight
                            )
                        }
                        
                        if let firstPoint = points.first {
                            path.move(to: firstPoint)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                    
                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, dataPoint in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .position(
                                x: 40 + (CGFloat(index) / CGFloat(data.count - 1)) * chartWidth,
                                y: 20 + (adjustedMaxWeight - dataPoint.weight) / adjustedRange * chartHeight
                            )
                    }
                }
                
                // X-axis labels
                VStack {
                    Spacer()
                    HStack {
                        ForEach(Array(data.enumerated().filter { $0.offset % max(1, data.count / 4) == 0 }), id: \.offset) { index, dataPoint in
                            Text(DateFormatter.shortDateFormatter.string(from: dataPoint.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if index < data.count - 1 { Spacer() }
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
    }
}

extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

struct WeightTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        WeightTrackingView()
            .environmentObject(TaskViewModel.createPreviewViewModel())
    }
}