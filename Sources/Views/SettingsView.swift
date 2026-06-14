import SwiftUI

/// 設定画面。AppStorage で永続化する。
struct SettingsView: View {
    @AppStorage(AppSettingsKey.idleThresholdMinutes)
    private var idleThresholdMinutes = AppSettingsDefault.idleThresholdMinutes
    @AppStorage(AppSettingsKey.allowConcurrentTracking)
    private var allowConcurrentTracking = AppSettingsDefault.allowConcurrentTracking

    var body: some View {
        Form {
            Section("アイドル検知") {
                Stepper(value: $idleThresholdMinutes, in: 1...120) {
                    HStack {
                        Text("離席と判定するまでの時間")
                        Spacer()
                        Text("\(idleThresholdMinutes) 分")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Text("入力がこの時間ない場合、稼働中のすべてのタイマーを自動停止します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("計測") {
                Toggle("複数プロジェクトの同時測定を許可する", isOn: $allowConcurrentTracking)
                Text("オフにすると、あるプロジェクトを開始したとき他の計測は自動停止します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
