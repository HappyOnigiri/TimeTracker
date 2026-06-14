# TimeTracker

macOS 向けのメニューバー常駐型タイムトラッキングアプリ（Swift / SwiftUI）。

## 必要環境

- macOS 14 以降
- Xcode 26 以降
- `xcodegen`, `swiftlint`（`brew install xcodegen swiftlint`）

## セットアップ / ビルド

```sh
make generate   # project.yml から TimeTracker.xcodeproj を生成
make build      # ad-hoc 署名でビルド
make test       # ユニットテスト
make ci         # lint + build + test
make install    # Release ビルドして /Applications に配置する（Xcode GUI 不要）
```

Xcode で開く場合は `make generate` 後に `TimeTracker.xcodeproj` を開く。

## 設計メモ

- **プロジェクト定義**: `project.yml`（xcodegen）。`.xcodeproj` は生成物のため Git 管理外。
- **データ永続化**: SwiftData。
- **グラフ**: Swift Charts。

## 権限・セキュリティ方針

- **App Sandbox は有効のまま運用する。**
- **アイドル検知**: `CGEventSourceSecondsSinceLastEventType` を使用する。これは HID の
  アイドル秒数を読むだけで、イベントタップと異なり**アクセシビリティ（入力監視）権限は不要**。
  App Sandbox 内でも権限ダイアログなしに動作する。
- **CSV 出力**: `NSSavePanel` でユーザーが選んだ場所にのみ書き込む
  （`com.apple.security.files.user-selected.read-write`）。サンドボックスを外さない。
  プロジェクト名は CSV インジェクション（数式実行）を防ぐため出力時に無害化する。

> サンドボックス解除やアクセシビリティ権限の付与は不要。
