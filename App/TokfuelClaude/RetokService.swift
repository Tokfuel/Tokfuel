import Foundation
import TokfuelCore

/// バンドルした retok（Python スクリプト）を実行して JSON レポートを得る。
public enum RetokService {
    private final class ProcessHolder: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?

        func install(_ process: Process) {
            lock.lock()
            self.process = process
            lock.unlock()
        }

        func clear() {
            lock.lock()
            process = nil
            lock.unlock()
        }

        func terminate() {
            lock.lock()
            let running = process
            lock.unlock()
            if running?.isRunning == true {
                running?.terminate()
            }
        }
    }

    public enum RetokError: LocalizedError {
        case scriptMissing
        case pythonMissing
        case runFailed(String)

        public var errorDescription: String? {
            switch self {
            case .scriptMissing: return "同梱の retok スクリプトが見つかりません"
            case .pythonMissing: return "python3 が見つかりません（Xcode Command Line Tools が必要です）"
            case .runFailed(let msg): return "retok の実行に失敗しました: \(msg)"
            }
        }
    }

    private static func findPython() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = ["-c", "pass"]
            p.standardError = FileHandle.nullDevice
            p.standardOutput = FileHandle.nullDevice
            do {
                try p.run()
                p.waitUntilExit()
                if p.terminationStatus == 0 { return path }
            } catch { continue }
        }
        return nil
    }

    public static func run(days: Int, lang: String, projectsDir: URL? = nil, provider: String? = nil) async throws -> RetokReport {
        guard let script = Bundle.module.url(forResource: "retok", withExtension: "py") else {
            throw RetokError.scriptMissing
        }
        guard let python = findPython() else {
            throw RetokError.pythonMissing
        }

        let holder = ProcessHolder()
        let worker = Task.detached(priority: .utility) {
            try Task.checkCancellation()
            let process = Process()
            holder.install(process)
            defer { holder.clear() }
            process.executableURL = URL(fileURLWithPath: python)
            var arguments = [script.path, "--json", "--days", "\(days)", "--lang", lang]
            if let projectsDir {
                arguments += ["--dirs", projectsDir.path]
            }
            if let provider {
                arguments += ["--provider", provider]
            }
            process.arguments = arguments
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            let stdoutReader = Task.detached {
                stdout.fileHandleForReading.readDataToEndOfFile()
            }
            let stderrReader = Task.detached {
                stderr.fileHandleForReading.readDataToEndOfFile()
            }
            try process.run()
            if Task.isCancelled { process.terminate() }
            process.waitUntilExit()
            let data = await stdoutReader.value
            let errorData = await stderrReader.value
            try Task.checkCancellation()
            guard process.terminationStatus == 0 else {
                let msg = String(data: errorData, encoding: .utf8) ?? "unknown"
                throw RetokError.runFailed(String(msg.prefix(200)))
            }
            return try JSONDecoder().decode(RetokReport.self, from: data)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
            holder.terminate()
        }
    }
}
