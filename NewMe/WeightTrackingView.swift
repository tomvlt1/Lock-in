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
            
            if !viewModel.weightEntries.isEmpty {
                let chartData = viewModel.getWeightEntriesForChart()

                if !chartData.isEmpty {
                    let currentWeight = chartData.last!
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(currentWeight.weight, specifier: "%.1f") kg")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            
                            Text("Last updated: \(currentWeight.date, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if chartData.count > 1 {
                            let startingWeight = chartData.first!
                            let totalChange = currentWeight.weight - startingWeight.weight
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                // Total progress from start
                                HStack(spacing: 4) {
                                    Image(systemName: totalChange >= 0 ? "arrow.up" : "arrow.down")
                                        .font(.caption)
                                        .foregroundColor(totalChange >= 0 ? .orange : .green)

                                    Text("\(totalChange >= 0 ? "+" : "")\(totalChange, specifier: "%.1f") kg")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(totalChange >= 0 ? .orange : .green)
                                    
                                    Text("total")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Recent change
                                if chartData.count >= 2 {
                                    let previousWeight = chartData[chartData.count - 2]
                                    let recentChange = currentWeight.weight - previousWeight.weight

                                    HStack(spacing: 4) {
                                        Image(systemName: recentChange >= 0 ? "arrow.up" : "arrow.down")
                                            .font(.caption2)
                                            .foregroundColor(recentChange >= 0 ? .red : .blue)

                                        Text("\(recentChange >= 0 ? "+" : "")\(recentChange, specifier: "%.1f") kg")
                                            .font(.caption2)
                                            .foregroundColor(recentChange >= 0 ? .red : .blue)

                                        Text("recent")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
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

            if chartData.count >= 1 {
                WeightLineChart(data: chartData)
                    .frame(height: 200)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("Add weight entries to see your progress chart")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
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
                LazyVStack(spacing: 8) {
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
        VStack(spacing: 12) {
            // Weight range info
            if let minWeight = data.map({$0.weight}).min(),
               let maxWeight = data.map({$0.weight}).max() {
                Text("Range: \(minWeight, specifier: "%.1f") - \(maxWeight, specifier: "%.1f") kg")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Bar chart representation
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, entry in
                        VStack(spacing: 6) {
                            // Weight value
                            Text("\(entry.weight, specifier: "%.1f")")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)

                            // Visual bar (height based on weight relative to range)
                            let minWeight = data.map({$0.weight}).min() ?? 0
                            let maxWeight = data.map({$0.weight}).max() ?? 100
                            let range = maxWeight - minWeight
                            let normalizedHeight: CGFloat = {
                                if data.count == 1 {
                                    return 60  // Fixed height for single entry
                                } else if range > 0 {
                                    return 20 + ((entry.weight - minWeight) / range) * 80
                                } else {
                                    return 50  // All entries same weight
                                }
                            }()

                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 24, height: normalizedHeight)
                                .cornerRadius(4)

                            // Date
                            Text(DateFormatter.shortDateFormatter.string(from: entry.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 120)
        }
        .padding()
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
