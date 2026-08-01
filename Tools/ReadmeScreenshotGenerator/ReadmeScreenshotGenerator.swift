import AppKit
import SwiftData
import SwiftUI

@main
@MainActor
struct ReadmeScreenshotGenerator {
    static func main() throws {
        guard let outputPath = CommandLine.arguments.dropFirst().first else {
            throw GeneratorError.outputDirectoryMissing
        }

        let outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Project.self,
            TimeLog.self,
            ActiveSession.self,
            configurations: configuration
        )
        let now = Date()
        let sampleMonth = ScreenshotSampleData.sampleMonth(containing: now)
        for language in [AppLanguage.english, .japanese] {
            try ScreenshotSampleData.replaceAll(
                in: container.mainContext,
                now: now,
                language: language
            )
            let languageDirectory = outputDirectory.appendingPathComponent(
                language.rawValue,
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: languageDirectory,
                withIntermediateDirectories: true
            )
            try render(
                DashboardView(selectedMonth: sampleMonth)
                    .modelContainer(container)
                    .environment(\.locale, language.locale)
                    .environment(\.colorScheme, .light)
                    .frame(width: 1_200, height: 800)
                    .background(Color(nsColor: .windowBackgroundColor)),
                size: CGSize(width: 1_200, height: 800),
                to: languageDirectory.appendingPathComponent("dashboard.png")
            )
        }
    }

    private static func render<Content: View>(
        _ content: Content,
        size: CGSize,
        to url: URL
    ) throws {
        let frame = CGRect(origin: .zero, size: size)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = frame
        hostingView.appearance = NSAppearance(named: .aqua)

        // ScrollView や Chart も描画ツリーへ参加できるよう、表示しないウィンドウ上でレイアウトする。
        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hostingView
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: frame) else {
            throw GeneratorError.renderFailed(url.lastPathComponent)
        }
        hostingView.cacheDisplay(in: frame, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw GeneratorError.pngEncodingFailed(url.lastPathComponent)
        }
        try data.write(to: url, options: .atomic)
        window.contentView = nil
    }
}

private enum GeneratorError: LocalizedError {
    case outputDirectoryMissing
    case renderFailed(String)
    case pngEncodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .outputDirectoryMissing:
            "出力先を指定してください。"
        case .renderFailed(let filename):
            "\(filename) の描画に失敗しました。"
        case .pngEncodingFailed(let filename):
            "\(filename) の PNG 変換に失敗しました。"
        }
    }
}
