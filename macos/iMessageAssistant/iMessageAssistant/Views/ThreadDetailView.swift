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
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(ctx.messages.indices, id: \.self) { i in
                            let msg = ctx.messages[i]
                            MessageBubble(text: msg.text, isFromMe: msg.is_from_me)
                        }
                    }
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

struct MessageBubble: View {
    let text: String
    let isFromMe: Bool

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 40) }
            Text(text)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isFromMe ? Color.blue : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isFromMe ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !isFromMe { Spacer(minLength: 40) }
        }
    }
}
