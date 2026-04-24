import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(.blue)
                Text("iMessage Assistant")
                    .font(.headline)
                Spacer()
                serverStatusDot
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            if let thread = appState.selectedThread {
                ThreadDetailView(thread: thread)
            } else {
                threadListView
            }

            Divider()

            // Footer
            HStack {
                if let err = appState.lastPollError {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 360)
    }

    @ViewBuilder
    private var serverStatusDot: some View {
        Circle()
            .fill(appState.serverReachable ? Color.green : Color.red)
            .frame(width: 8, height: 8)
            .help(appState.serverReachable ? "Bridge server running" : "Bridge server not running")
    }

    @ViewBuilder
    private var threadListView: some View {
        if appState.pendingThreads.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No pending messages")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List(appState.pendingThreads) { thread in
                ThreadRowView(thread: thread)
                    .onTapGesture {
                        appState.loadDrafts(for: thread)
                    }
            }
            .listStyle(.plain)
        }
    }
}
