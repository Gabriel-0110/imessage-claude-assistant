import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var pendingThreads: [PendingThread] = []
    @Published var selectedThread: PendingThread?
    @Published var draftContext: DraftContext?
    @Published var drafts: [DraftOption] = []
    @Published var isGeneratingDrafts = false
    @Published var draftError: String?
    @Published var serverReachable = false
    @Published var lastPollError: String?

    private var knownGuids: Set<String> = []
    private var pollingTask: Task<Void, Never>?

    func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                await poll()
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Polling

    private func poll() async {
        let reachable = await BridgeClient.shared.healthCheck()
        serverReachable = reachable
        guard reachable else {
            lastPollError = "Bridge server not reachable on localhost:7842"
            return
        }
        lastPollError = nil

        do {
            let threads = try await BridgeClient.shared.fetchPending(lookbackHours: 2)
            let newGuids = Set(threads.map(\.chat_guid))
            let brandNew = newGuids.subtracting(knownGuids)

            pendingThreads = threads
            knownGuids = newGuids
            NotificationCenter.default.post(name: .pendingCountChanged, object: nil)

            for thread in threads where brandNew.contains(thread.chat_guid) {
                NotificationService.shared.fireNotification(for: thread)
            }
        } catch {
            lastPollError = error.localizedDescription
        }
    }

    // MARK: - Draft Generation

    func loadDrafts(for thread: PendingThread) {
        selectedThread = thread
        drafts = []
        draftError = nil
        isGeneratingDrafts = true
        draftContext = nil

        Task {
            do {
                let ctx = try await BridgeClient.shared.fetchDraftContext(chatGuid: thread.chat_guid)
                draftContext = ctx
                let options = try await DraftService.generateDrafts(context: ctx)
                drafts = options
            } catch {
                draftError = error.localizedDescription
            }
            isGeneratingDrafts = false
        }
    }

    // MARK: - Send

    func sendReply(text: String, signature: String?) async {
        guard let thread = selectedThread else { return }
        do {
            try await BridgeClient.shared.sendReply(
                chatGuid: thread.chat_guid,
                text: text,
                signature: signature
            )
            // Remove from pending list
            pendingThreads.removeAll { $0.chat_guid == thread.chat_guid }
            knownGuids.remove(thread.chat_guid)
            selectedThread = nil
            drafts = []
            draftContext = nil
        } catch {
            draftError = error.localizedDescription
        }
    }

    func ignore(thread: PendingThread) {
        // Remove locally — will reappear next poll if still unreplied (by design)
        pendingThreads.removeAll { $0.chat_guid == thread.chat_guid }
        knownGuids.remove(thread.chat_guid)
        if selectedThread?.chat_guid == thread.chat_guid {
            selectedThread = nil
            drafts = []
        }
    }
}
