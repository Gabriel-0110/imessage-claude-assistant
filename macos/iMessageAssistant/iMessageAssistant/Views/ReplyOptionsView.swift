import SwiftUI

struct ReplyOptionsView: View {
    @EnvironmentObject var appState: AppState
    let thread: PendingThread

    @State private var selectedIndex: Int = 0
    @State private var editedTexts: [String] = []
    @State private var signatureMode: SignatureMode = .keep
    @State private var customSignature: String = ""
    @State private var isSending = false

    enum SignatureMode: String, CaseIterable {
        case keep = "Keep signature"
        case remove = "Remove signature"
        case custom = "Custom..."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose a reply:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)

                ForEach(appState.drafts.indices, id: \.self) { i in
                    draftCard(index: i)
                }

                signaturePicker

                HStack(spacing: 10) {
                    Button(isSending ? "Sending…" : "Send") {
                        send()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending || editedTexts.indices.contains(selectedIndex) && editedTexts[selectedIndex].isEmpty)

                    Button("Ignore") {
                        appState.ignore(thread: thread)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            editedTexts = appState.drafts.map(\.text)
        }
        .onChange(of: appState.drafts) { _, drafts in
            editedTexts = drafts.map(\.text)
            selectedIndex = 0
        }
    }

    @ViewBuilder
    private func draftCard(index: Int) -> some View {
        let isSelected = index == selectedIndex
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(appState.drafts[index].label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .blue : .secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            if isSelected && editedTexts.indices.contains(index) {
                TextEditor(text: $editedTexts[index])
                    .font(.callout)
                    .frame(minHeight: 44)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(appState.drafts[index].text)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.07) : Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture { selectedIndex = index }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var signaturePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Signature", selection: $signatureMode) {
                ForEach(SignatureMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            if signatureMode == .custom {
                TextField("Custom signature", text: $customSignature)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func send() {
        guard editedTexts.indices.contains(selectedIndex) else { return }
        let text = editedTexts[selectedIndex]
        let signature: String? = {
            switch signatureMode {
            case .keep: return "default"
            case .remove: return "none"
            case .custom: return customSignature.isEmpty ? "default" : customSignature
            }
        }()
        isSending = true
        Task {
            await appState.sendReply(text: text, signature: signature)
            isSending = false
        }
    }
}
