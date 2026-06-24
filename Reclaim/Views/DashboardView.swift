import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    
    // Live system stats state variables
    @State private var ramUsed: Int64 = 0
    @State private var ramTotal: Int64 = 16 * 1024 * 1024 * 1024
    @State private var ramPercentage: Double = 0.0
    
    @State private var diskUsed: Int64 = 0
    @State private var diskTotal: Int64 = 512 * 1024 * 1024 * 1024
    @State private var diskPercentage: Double = 0.0
    
    // Timer to poll CPU/RAM usage updates
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reclaim Dashboard")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Evaluate your Mac's speed and storage health.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            
            // Gauges Row
            HStack(spacing: 40) {
                CircularGauge(
                    title: "Storage",
                    percentage: diskPercentage,
                    valueString: "\(ByteCountFormatter.string(fromByteCount: diskUsed, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: diskTotal, countStyle: .file))",
                    gradient: Gradient(colors: [.indigo, .purple])
                )
                
                CircularGauge(
                    title: "Memory (RAM)",
                    percentage: ramPercentage,
                    valueString: "\(ByteCountFormatter.string(fromByteCount: ramUsed, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: ramTotal, countStyle: .file))",
                    gradient: Gradient(colors: [.teal, .blue])
                )
                
                CircularGauge(
                    title: "System Junk",
                    percentage: appState.totalJunkSize > 0 ? 0.8 : 0.0,
                    valueString: appState.totalJunkSize > 0 ? "\(ByteCountFormatter.string(fromByteCount: appState.totalJunkSize, countStyle: .file)) detected" : "Clean",
                    gradient: Gradient(colors: [.orange, .red])
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Interaction Area
            VStack(spacing: 16) {
                if appState.isScanning {
                    // Scanning state
                    VStack(spacing: 20) {
                        ProgressView(value: appState.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 400)
                            .tint(.purple)
                        
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(appState.statusMessage)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(width: 500)
                        }
                    }
                } else if appState.isCleaning {
                    // Cleaning state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.orange)
                        Text(appState.statusMessage)
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                } else {
                    // Action Buttons
                    HStack(spacing: 20) {
                        Button {
                            Task {
                                await appState.startQuickScan()
                            }
                        } label: {
                            Text("Start Analyzer")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .cornerRadius(30)
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        
                        if appState.totalJunkSize > 0 {
                            Button {
                                Task {
                                    await appState.cleanSelectedJunk()
                                }
                            } label: {
                                Text("Clean selected (\(ByteCountFormatter.string(fromByteCount: appState.selectedJunkSize, countStyle: .file)))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .cornerRadius(30)
                                    .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text(appState.statusMessage)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 60)
        }
        .onAppear {
            updateStats()
        }
        .onReceive(timer) { _ in
            updateStats()
        }
    }
    
    private func updateStats() {
        let ram = SystemStats.memoryUsage()
        ramUsed = ram.used
        ramTotal = ram.total
        ramPercentage = ram.percentage
        
        let disk = SystemStats.diskUsage()
        diskUsed = disk.used
        diskTotal = disk.total
        diskPercentage = disk.percentage
    }
}

// Custom circular gauge widget
struct CircularGauge: View {
    let title: String
    let percentage: Double
    let valueString: String
    let gradient: Gradient
    
    @State private var animatedPercentage: Double = 0.0
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 16)
                    .frame(width: 160, height: 160)
                
                // Accent gradient circle
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(animatedPercentage, 1.0)))
                    .stroke(
                        AngularGradient(
                            gradient: gradient,
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 160, height: 160)
                
                VStack(spacing: 4) {
                    Text(String(format: "%.0f%%", animatedPercentage * 100))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(valueString)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 180)
        }
        .padding(20)
        .background(.white.opacity(0.04))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8, blendDuration: 0.5)) {
                animatedPercentage = percentage
            }
        }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8, blendDuration: 0.5)) {
                animatedPercentage = newValue
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .background(.black)
}
