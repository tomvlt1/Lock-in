import SwiftUI

struct MetricsView: View {
    private enum MetricTab: String, CaseIterable {
        case weight = "Weight"
        case plank = "Plank"
    }
    
    @State private var selectedTab: MetricTab = .weight
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(MetricTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color(.systemGroupedBackground))
                
                TabView(selection: $selectedTab) {
                    WeightTrackingView()
                        .tag(MetricTab.weight)
                        .tabItem { EmptyView() }
                    
                    PlankTrackingView()
                        .tag(MetricTab.plank)
                        .tabItem { EmptyView() }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Metrics")
        }
    }
}
