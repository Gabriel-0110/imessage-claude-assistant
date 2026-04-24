import Foundation

/// Spawns `claude -p` to generate 3 draft reply options from thread context.
struct DraftService {
    private static func findClaudePath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? "\(home)/.local/bin/claude"
    }

    static func generateDrafts(context: DraftContext) async throws -> [DraftOption] {
        let prompt = buildPrompt(context: context)
        let output = try await runClaude(prompt: prompt)
        return parseDrafts(output: output)
    }

    // MARK: - Prompt

    private static func buildPrompt(context: DraftContext) -> String {
        let contact = context.participants.first ?? "this person"
        let styleNote = context.style_notes.map { "\n\nStyle notes for this contact: \($0)" } ?? ""
        let thread = context.formattedThread

        return """
        You are Gabriel's iMessage reply assistant. Generate exactly 3 short reply options for the conversation below.

        Return ONLY valid JSON — no markdown, no explanation, just the JSON object:
        {"options":[{"label":"Safest/Neutral","text":"..."},{"label":"Warm/Natural","text":"..."},{"label":"Shortest","text":"..."}]}

        Rules:
        - Each reply should be concise, human, and natural — not robotic or overly formal
        - Option 1 (Safest/Neutral): safe, non-committal, friendly
        - Option 2 (Warm/Natural): warm, personal, conversational
        - Option 3 (Shortest): minimum words to convey the same meaning
        - Do NOT include a "Sent by Claude" signature\(styleNote)

        Conversation with \(contact) (oldest → newest):
        \(thread)
        """
    }

    // MARK: - Process

    private static func runClaude(prompt: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: findClaudePath())
            process.arguments = ["-p", prompt]

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            // 30-second timeout
            let timeoutTask = DispatchWorkItem {
                if process.isRunning { process.terminate() }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutTask)

            process.terminationHandler = { proc in
                timeoutTask.cancel()
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
                    continuation.resume(throwing: DraftError.claudeFailed(errMsg))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parse

    private static func parseDrafts(output: String) -> [DraftOption] {
        // Find the JSON object in the output (claude -p may include extra text)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonStart = trimmed.firstIndex(of: "{"),
              let jsonEnd = trimmed.lastIndex(of: "}") else {
            // Fallback: return raw output as a single option
            return [DraftOption(label: "Reply", text: trimmed)]
        }

        let jsonStr = String(trimmed[jsonStart...jsonEnd])
        guard let data = jsonStr.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(DraftResponse.self, from: data) else {
            return [DraftOption(label: "Reply", text: trimmed)]
        }

        return parsed.options.map { DraftOption(label: $0.label, text: $0.text) }
    }

    enum DraftError: LocalizedError {
        case claudeFailed(String)

        var errorDescription: String? {
            switch self {
            case .claudeFailed(let msg): return "claude -p failed: \(msg)"
            }
        }
    }
}

private struct DraftResponse: Decodable {
    struct Option: Decodable {
        let label: String
        let text: String
    }
    let options: [Option]
}
