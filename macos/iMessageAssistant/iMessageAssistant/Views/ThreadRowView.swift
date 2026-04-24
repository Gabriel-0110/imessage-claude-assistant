import SwiftUI

struct ThreadRowView: View {
    let thread: PendingThread

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: thread.kind == "group" ? "person.3.fill" : "person.fill")
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(thread.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    Text(thread.relativeTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let preview = thread.preview {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
