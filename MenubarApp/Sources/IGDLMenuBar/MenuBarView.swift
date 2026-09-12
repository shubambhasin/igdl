import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var manager: DownloadManager
    @State private var urlText: String = ""
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(alignment: .leading, spacing: 8) {
                TextField("Paste an Instagram URL…", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(igdlGradient.opacity(0.5), lineWidth: 1.2)
                    )
                    .onSubmit(submit)

                HStack(spacing: 8) {
                    Button(action: submit) {
                        Label("Download", systemImage: "arrow.down.to.line")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(manager.isDownloading || urlText.isEmpty)

                    Button(action: pasteFromClipboard) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(GradientOutlineButtonStyle())
                    .disabled(manager.isDownloading)
                    .help("Paste from Clipboard")
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
        .padding(14)
        .frame(width: 320)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.10), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
        )
        .sheet(isPresented: $showingSettings) {
            SettingsView(manager: manager, isPresented: $showingSettings)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(igdlGradient)
                    .frame(width: 28, height: 28)
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("igdl")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(igdlGradient)
                Text("Instagram reel & post downloader")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("Downloading…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func errorRow(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(manager.records.enumerated()), id: \.element.id) { index, record in
                            if index > 0 { Divider() }
                            RecordRow(record: record)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings…") { showingSettings = true }
                .buttonStyle(GradientTextButtonStyle())
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(GradientTextButtonStyle())
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
        HStack(alignment: .top, spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(record.success
                      ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom))
                .frame(width: 3)
                .padding(.vertical, 1)

            VStack(alignment: .leading, spacing: 1) {
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
        .padding(.vertical, 6)
    }
}

struct SettingsView: View {
    @ObservedObject var manager: DownloadManager
    @Binding var isPresented: Bool
    @State private var outputDirectory: String = ""
    @State private var igdlPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(igdlGradient).frame(width: 24, height: 24)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
                Text("igdl Settings")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(igdlGradient)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Output directory").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("~/Downloads", text: $outputDirectory)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { chooseDirectory() }
                        .buttonStyle(GradientOutlineButtonStyle())
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
                    .buttonStyle(GradientTextButtonStyle())
                Button("Save") {
                    manager.outputDirectory = outputDirectory
                    UserDefaults.standard.set(igdlPath, forKey: "igdlPath")
                    isPresented = false
                }
                .buttonStyle(GradientButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
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
