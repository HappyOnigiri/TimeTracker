import SwiftUI

/// アイドル自動停止時に表示する通知ビュー。
struct IdleStopAlertView: View {
    let engine: TimerEngine

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("タイマーを自動停止しました")
                .font(.headline)

            if !engine.idleStoppedProjectNames.isEmpty {
                Text(engine.idleStoppedProjectNames.joined(separator: "、"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("一定時間入力がなかったため、計測を自動的に停止しました。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("閉じる") {
                    engine.dismissIdleNotification()
                }
                .keyboardShortcut(.cancelAction)

                Button("計測を再開") {
                    engine.resumeAfterIdle()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
