import SwiftUI

struct ContentView: View {
    @StateObject private var store = DownloadStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            urlInput
            destinationRow
            actionRow
            logPanel
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 440)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            Text("링크 다운로드")
                .font(.title2.weight(.semibold))

            Spacer()

            StatusBadge(text: store.statusMessage, isActive: store.isDownloading)
        }
    }

    private var urlInput: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .frame(width: 24)
                .foregroundStyle(.secondary)

            TextField("X/Twitter 또는 영상 주소", text: $store.urlText)
                .textFieldStyle(.roundedBorder)
                .disabled(store.isDownloading)
                .onSubmit(store.startDownload)

            Button(action: store.pasteFromClipboard) {
                Image(systemName: "doc.on.clipboard")
                    .frame(width: 18, height: 18)
            }
            .help("클립보드 붙여넣기")
            .disabled(store.isDownloading)
        }
    }

    private var destinationRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .frame(width: 24)
                .foregroundStyle(.secondary)

            Text(store.destinationURL.path)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: store.selectDestination) {
                Image(systemName: "folder.badge.gearshape")
                    .frame(width: 18, height: 18)
            }
            .help("저장 위치 선택")
            .disabled(store.isDownloading)

            Button(action: store.revealDestination) {
                Image(systemName: "arrow.up.forward.app")
                    .frame(width: 18, height: 18)
            }
            .help("Finder에서 보기")
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button(action: store.startDownload) {
                Label("다운로드", systemImage: "arrow.down.circle.fill")
                    .frame(minWidth: 104)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!store.canStart)

            if store.isDownloading {
                Button(action: store.cancelDownload) {
                    Label("중지", systemImage: "stop.circle")
                }
            }

            if store.isDownloading {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()
        }
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("로그")
                .font(.headline)

            ScrollView {
                Text(store.logText.isEmpty ? "다운로드 로그가 표시됩니다." : store.logText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(store.logText.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(minHeight: 210)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.blue : Color.secondary.opacity(0.55))
                .frame(width: 8, height: 8)

            Text(text)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
        .frame(maxWidth: 280, alignment: .trailing)
    }
}
