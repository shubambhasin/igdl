import Foundation

struct DownloadRecord: Identifiable {
    let id = UUID()
    let url: String
    let path: String?
    let sizeMB: Double?
    let success: Bool
    let message: String
    let date = Date()
}

enum IGDLLocator {
    /// Resolution order: explicit override in Settings, the project-local venv
    /// this app ships alongside, common Homebrew/venv locations, then PATH.
    static func findExecutable() -> String? {
        let candidates = [
            UserDefaults.standard.string(forKey: "igdlPath"),
            NSHomeDirectory() + "/Desktop/igdl/.venv/bin/igdl",
            "/usr/local/bin/igdl",
            "/opt/homebrew/bin/igdl",
        ].compactMap { $0 }.filter { !$0.isEmpty }

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        which.arguments = ["which", "igdl"]
        let pipe = Pipe()
        which.standardOutput = pipe
        do {
            try which.run()
            which.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else {
            return nil
        }
        return str
    }
}

final class DownloadManager: ObservableObject {
    @Published var isDownloading = false
    @Published var records: [DownloadRecord] = []
    @Published var lastError: String?

    private let maxRecords = 20
    private let defaults = UserDefaults.standard

    var outputDirectory: String {
        get { defaults.string(forKey: "outputDirectory") ?? (NSHomeDirectory() + "/Downloads") }
        set { defaults.set(newValue, forKey: "outputDirectory") }
    }

    func download(url rawURL: String) {
        guard !isDownloading else { return }
        let url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard url.contains("instagram.com") else {
            lastError = "Not an Instagram URL: \(url)"
            return
        }
        guard let exe = IGDLLocator.findExecutable() else {
            lastError = "igdl CLI not found. Run `make setup` in the igdl project (see README), " +
                        "or set a custom path in Settings."
            return
        }

        isDownloading = true
        lastError = nil
        let outDir = outputDirectory

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: exe)
            process.arguments = [url, "-o", outDir]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let record: DownloadRecord
            do {
                try process.run()
                process.waitUntilExit()

                let out = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    let (path, size) = Self.parseSuccess(out)
                    record = DownloadRecord(
                        url: url, path: path, sizeMB: size, success: true,
                        message: out.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                } else {
                    let message = (err.isEmpty ? out : err).trimmingCharacters(in: .whitespacesAndNewlines)
                    record = DownloadRecord(url: url, path: nil, sizeMB: nil, success: false, message: message)
                }
            } catch {
                record = DownloadRecord(url: url, path: nil, sizeMB: nil, success: false, message: error.localizedDescription)
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isDownloading = false
                self.records.insert(record, at: 0)
                if self.records.count > self.maxRecords {
                    self.records.removeLast(self.records.count - self.maxRecords)
                }
                if !record.success {
                    self.lastError = record.message
                }
            }
        }
    }

    private static func parseSuccess(_ output: String) -> (String?, Double?) {
        guard let markerRange = output.range(of: "saved: ") else { return (nil, nil) }
        let rest = output[markerRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parenRange = rest.range(of: " (") else { return (rest, nil) }
        let path = String(rest[rest.startIndex..<parenRange.lowerBound])
        let sizeString = rest[parenRange.upperBound...].replacingOccurrences(of: " MB)", with: "")
        return (path, Double(sizeString))
    }
}
