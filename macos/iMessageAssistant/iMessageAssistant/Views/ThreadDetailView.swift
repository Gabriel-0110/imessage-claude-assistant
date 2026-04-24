import SwiftUI

struct ThreadDetailView: View {
    @EnvironmentObject var appState: AppState
    let thread: PendingThread

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: { appState.selectedThread = nil }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(thread.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Ignore") {
                    appState.ignore(thread: thread)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Message history
            if let ctx = appState.draftContext {
                ScrollView {
                    Text(ctx.formattedThread)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 160)
            } else if appState.isGeneratingDrafts {
                ProgressView("Loading...")
                    .frame(maxHeight: 80)
            }

            Divider()

            // Draft options or loading state
            if appState.isGeneratingDrafts && appState.draftContext != nil {
                VStack(spacing: 8) {
                    ProgressView("Generating replies...")
                    Text("Asking Claude for 3 options…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else if let err = appState.draftError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(err)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button("Retry") { appState.loadDrafts(for: thread) }
                }
                .padding()
            } else if !appState.drafts.isEmpty {
                ReplyOptionsView(thread: thread)
            } else {
                Button("Generate Replies") {
                    appState.loadDrafts(for: thread)
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
    }
}

