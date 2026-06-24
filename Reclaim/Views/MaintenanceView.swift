import SwiftUI

struct MaintenanceView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maintenance Tasks")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Run diagnostic scripts and flush system caches to optimize performance.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.white.opacity(0.01))
            
            Divider()
            
            // Tasks List
            List {
                ForEach(state.maintenanceTasks.indices, id: \.self) { index in
                    let task = state.maintenanceTasks[index]
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 16) {
                            Toggle("", isOn: $state.maintenanceTasks[index].isChecked)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                .padding(.top, 4)
                            
                            Image(systemName: task.systemIcon)
                                .font(.title)
                                .foregroundColor(.teal)
                                .frame(width: 36, height: 36)
                                .background(Color.teal.opacity(0.1))
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(task.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(task.details)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                
                                // Render task running state
                                taskStatusIndicator(status: task.status)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        
                        Divider()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            
            // Run Bar
            if state.maintenanceTasks.contains(where: { $0.isChecked }) {
                Divider()
                HStack {
                    Text("Selected tasks will be executed sequentially.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Spacer()
                    
                    let isAnyRunning = state.maintenanceTasks.contains(where: {
                        if case .running = $0.status { return true }
                        return false
                    })
                    
                    Button {
                        runSelectedTasks()
                    } label: {
                        HStack(spacing: 8) {
                            if isAnyRunning {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isAnyRunning ? "Running Tasks..." : "Run Tasks")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(isAnyRunning)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
    
    @ViewBuilder
    private func taskStatusIndicator(status: TaskStatus) -> some View {
        switch status {
        case .idle:
            EmptyView()
        case .running(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 120)
                    .tint(.teal)
                Text("Executing...")
                    .font(.caption)
                    .foregroundColor(.teal)
            }
            .padding(.top, 4)
        case .completed(let summary):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding(.top, 4)
        case .failed(let error):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(.top, 4)
        }
    }
    
    private func runSelectedTasks() {
        Task {
            for index in appState.maintenanceTasks.indices {
                guard appState.maintenanceTasks[index].isChecked else { continue }
                
                let taskId = appState.maintenanceTasks[index].id
                appState.maintenanceTasks[index].status = .running(progress: 0.1)
                
                do {
                    let result = try await appState.maintenance.executeTask(id: taskId) { progress in
                        // Perform state updates on main thread
                        Task { @MainActor in
                            appState.maintenanceTasks[index].status = .running(progress: progress)
                        }
                    }
                    appState.maintenanceTasks[index].status = .completed(summary: result)
                } catch {
                    appState.maintenanceTasks[index].status = .failed(error: error.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    MaintenanceView()
        .environment(AppState())
        .background(.black)
}
