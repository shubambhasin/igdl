import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var manager: DownloadManager
    @State private var urlText: String = ""
    @State private var showingSettings = false
    @Namespace private var glassNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            GlassEffectContainer(spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Paste an Instagram URL…", text: $urlText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .onSubmit(submit)

                    HStack(spacing: 8) {
                        Button(action: submit) {
                            Label("Download", systemImage: "arrow.down.to.line")
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                        .disabled(manager.isDownloading || urlText.isEmpty)

                        Button(action: pasteFromClipboard) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.glass)
                        .disabled(manager.isDownloading)
                        .help("Paste from Clipboard")
                    }
                }
            }

            if manager.isDownloading {
                statusRow
            }

            if let error = manager.lastError {
                errorRow(error)
            }

            Divider()

            recentSection

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 340)
        .sheet(isPresented: $showingSettings) {
            SettingsView(manager: manager, isPresented: $showingSettings)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 1) {
                Text("igdl").font(.system(size: 14, weight: .semibold))
                Text("Instagram reel & post downloader")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Downloading…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func errorRow(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(.red.opacity(0.15)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if manager.records.isEmpty {
                Text("Nothing downloaded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 6) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(manager.records) { record in
                                RecordRow(record: record)
                            }
                        }
                    }
                }
                .frame(maxHeight: 190)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings…") { showingSettings = true }
                .buttonStyle(.glass)
                .controlSize(.small)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.glass)
                .controlSize(.small)
        }
    }

    private func submit() {
        guard !urlText.isEmpty else { return }
        manager.download(url: urlText)
        urlText = ""
    }

    private func pasteFromClipboard() {
        if let clip = clipboardInstagramURL() {
            urlText = clip
            submit()
        } else {
            manager.lastError = "No Instagram URL found on the clipboard."
        }
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
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(record.success ? .green : .red)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.url)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if record.success, let path = record.path {
                    let name = (path as NSString).lastPathComponent
                    let sizeText = record.sizeMB.map { String(format: " · %.1f MB", $0) } ?? ""
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
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct SettingsView: View {
    @ObservedObject var manager: DownloadManager
    @Binding var isPresented: Bool
    @State private var outputDirectory: String = ""
    @State private var igdlPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                Text("igdl Settings").font(.system(size: 14, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Output directory").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("~/Downloads", text: $outputDirectory)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Button("Choose…") { chooseDirectory() }
                        .buttonStyle(.glass)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("igdl executable path (optional override)").font(.caption).foregroundStyle(.secondary)
                TextField("auto-detected", text: $igdlPath)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.glass)
                Button("Save") {
                    manager.outputDirectory = outputDirectory
                    UserDefaults.standard.set(igdlPath, forKey: "igdlPath")
                    isPresented = false
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
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
