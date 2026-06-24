import SwiftUI

/// アイドル自動停止時に表示する通知ビュー。
struct IdleStopAlertView: View {
    let engine: TimerEngine

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("タイマーを自動停止しました")
                .font(.title2.bold())

            if !engine.idleStoppedProjectNames.isEmpty {
                Text(engine.idleStoppedProjectNames.joined(separator: "、"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("一定時間入力がなかったため、計測を自動的に停止しました。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("閉じる") {
                    engine.dismissIdleNotification()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Button("計測を再開") {
                    engine.resumeAfterIdle()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 440)
    }
}
