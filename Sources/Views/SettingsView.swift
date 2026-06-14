import SwiftUI

/// 設定画面。AppStorage で永続化する。
struct SettingsView: View {
    /// アイドル時間の設定範囲（分）。
    private static let thresholdRange = 1...120

    @AppStorage(AppSettingsKey.idleDetectionEnabled)
    private var idleDetectionEnabled = AppSettingsDefault.idleDetectionEnabled
    @AppStorage(AppSettingsKey.idleThresholdMinutes)
    private var idleThresholdMinutes = AppSettingsDefault.idleThresholdMinutes
    @AppStorage(AppSettingsKey.allowConcurrentTracking)
    private var allowConcurrentTracking = AppSettingsDefault.allowConcurrentTracking

    /// 範囲内にクランプした分数のバインディング（数値入力の範囲外対策）。
    private var clampedMinutes: Binding<Int> {
        Binding(
            get: { idleThresholdMinutes },
            set: { idleThresholdMinutes = min(max($0, Self.thresholdRange.lowerBound), Self.thresholdRange.upperBound) }
        )
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
