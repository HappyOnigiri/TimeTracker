import SwiftUI

/// 設定画面。AppStorage で永続化する。
struct SettingsView: View {
    /// アイドル時間の設定範囲（分）。
    private static let thresholdRange = 0...120

    @AppStorage(AppSettingsKey.idleDetectionEnabled)
    private var idleDetectionEnabled = AppSettingsDefault.idleDetectionEnabled
    @AppStorage(AppSettingsKey.idleThresholdMinutes)
    private var idleThresholdMinutes = AppSettingsDefault.idleThresholdMinutes
    @AppStorage(AppSettingsKey.idleAlertEnabled)
    private var idleAlertEnabled = AppSettingsDefault.idleAlertEnabled
    @AppStorage(AppSettingsKey.allowConcurrentTracking)
    private var allowConcurrentTracking = AppSettingsDefault.allowConcurrentTracking
    @AppStorage(AppSettingsKey.timelineSnapMinutes)
    private var timelineSnapMinutes = AppSettingsDefault.timelineSnapMinutes
    @AppStorage(AppSettingsKey.promptForWorkNoteOnStop)
    private var promptForWorkNoteOnStop = AppSettingsDefault.promptForWorkNoteOnStop

    /// ログイン項目（自動起動）の登録状態。システム側の状態を反映する。
    @State private var launchAtLogin = LoginItemService.isEnabled
    @State private var launchAtLoginError: String?

    /// アプリのバージョン（CFBundleShortVersionString）。Info.plist を唯一の真実の源とする。
    private static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"

    /// 範囲内にクランプした分数のバインディング（数値入力の範囲外対策）。
    private var clampedMinutes: Binding<Int> {
        Binding(
            get: { idleThresholdMinutes },
            set: { idleThresholdMinutes = min(max($0, Self.thresholdRange.lowerBound), Self.thresholdRange.upperBound) }
        )
    }

    /// 自動起動の切り替えを反映する。失敗時はトグルを実状態へ戻しエラーを表示する。
    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLogin = LoginItemService.isEnabled
            launchAtLoginError = "設定の変更に失敗しました: \(error.localizedDescription)"
        }
    }

    var body: some View {
        Form {
            Section("アイドル検知") {
                Toggle("離席判定を有効にする", isOn: $idleDetectionEnabled)
                HStack {
                    Text("離席と判定するまでの時間")
                    Spacer()
                    TextField("分", value: clampedMinutes, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 48)
                    Text("分")
                        .foregroundStyle(.secondary)
                    Stepper(value: clampedMinutes, in: Self.thresholdRange) {
                        EmptyView()
                    }
                    .labelsHidden()
                }
                .disabled(!idleDetectionEnabled)
                Text("入力がこの時間ない場合、稼働中のすべてのタイマーを自動停止します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("自動停止時にモーダルを表示する", isOn: $idleAlertEnabled)
                    .disabled(!idleDetectionEnabled)
            }
            Section("計測") {
                Toggle("複数プロジェクトの同時測定を許可する", isOn: $allowConcurrentTracking)
                Text("オフにすると、あるプロジェクトを開始したとき他の計測は自動停止します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("計測停止時に作業内容の入力を促す", isOn: $promptForWorkNoteOnStop)
                Text("計測を停止したとき、またはアイドルで自動停止したときに作業内容を入力するダイアログを表示します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("タイムライン") {
                Picker("ドラッグ操作のスナップ単位", selection: $timelineSnapMinutes) {
                    Text("5 分").tag(5)
                    Text("10 分").tag(10)
                    Text("15 分").tag(15)
                    Text("30 分").tag(30)
                }
                Text("タイムラインでブロックを移動・リサイズしたときの時刻の丸め幅です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("起動") {
                Toggle("Mac 起動時に自動的に開く", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section("情報") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(Self.appVersion)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // 設定アプリ等で外部変更され得るため、表示のたびに実状態へ同期する。
            launchAtLogin = LoginItemService.isEnabled
        }
    }
}

#Preview {
    SettingsView()
}
