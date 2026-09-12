import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var manager: DownloadManager
    @State private var urlText: String = ""
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("igdl").font(.headline)

            TextField("Instagram reel/post URL", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            HStack {
                Button("Download", action: submit)
                    .disabled(manager.isDownloading || urlText.isEmpty)

                Button("Paste from Clipboard") {
                    if let clip = clipboardInstagramURL() {
                        urlText = clip
                        submit()
                    } else {
                        manager.lastError = "No Instagram URL found on the clipboard."
                    }
                }
                .disabled(manager.isDownloading)
            }

            if manager.isDownloading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Downloading…").foregroundStyle(.secondary)
                }
            }

            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Text("Recent").font(.subheadline).foregroundStyle(.secondary)

            if manager.records.isEmpty {
                Text("Nothing downloaded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(manager.records) { record in
                            RecordRow(record: record)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            Divider()

            HStack {
                Button("Settings…") { showingSettings = true }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 320)
        .sheet(isPresented: $showingSettings) {
            SettingsView(manager: manager, isPresented: $showingSettings)
        }
    }

    private func submit() {
        guard !urlText.isEmpty else { return }
        manager.download(url: urlText)
        urlText = ""
    }

    private func clipboardInstagramURL() -> String? {
        guard let value = NSPasteboard.general.string(forType: .string),
              value.contains("instagram.com") else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct RecordRow: View {
    let record: DownloadRecord

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(record.success ? .green : .red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.url)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if record.success, let path = record.path {
                    let name = (path as NSString).lastPathComponent
                    let sizeText = record.sizeMB.map { String(format: " (%.1f MB)", $0) } ?? ""
                    Button("\(name)\(sizeText)") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                    .buttonStyle(.link)
                    .font(.caption2)
                } else if !record.success {
                    Text(record.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var manager: DownloadManager
    @Binding var isPresented: Bool
    @State private var outputDirectory: String = ""
    @State private var igdlPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("igdl Settings").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Output directory").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("~/Downloads", text: $outputDirectory)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { chooseDirectory() }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("igdl executable path (optional override)").font(.caption).foregroundStyle(.secondary)
                TextField("auto-detected", text: $igdlPath)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") {
                    manager.outputDirectory = outputDirectory
                    UserDefaults.standard.set(igdlPath, forKey: "igdlPath")
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            outputDirectory = manager.outputDirectory
            igdlPath = UserDefaults.standard.string(forKey: "igdlPath") ?? ""
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url.path
        }
    }
}
