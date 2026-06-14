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
```

Xcode で開く場合は `make generate` 後に `TimeTracker.xcodeproj` を開く。

## 設計メモ

- **プロジェクト定義**: `project.yml`（xcodegen）。`.xcodeproj` は生成物のため Git 管理外。
- **データ永続化**: SwiftData（Step 2 以降）。
- **グラフ**: Swift Charts（Step 4）。

## 権限・セキュリティ方針

- **App Sandbox は有効のまま運用する。**
- **アイドル検知**: `CGEventSourceSecondsSinceLastEventType` を使用する。これは HID の
  アイドル秒数を読むだけで、イベントタップと異なり**アクセシビリティ（入力監視）権限は不要**。
  サンドボックス内でも権限ダイアログなしに動作する見込み。Step 3 で実機検証する。
- **CSV 出力**: `NSSavePanel` でユーザーが選んだ場所にのみ書き込む
  （`com.apple.security.files.user-selected.read-write`）。サンドボックスを外さない。

> 現状、サンドボックス解除やアクセシビリティ権限付与が必要になる見込みはない。
> Step 3 の実機検証で必要と判明した場合は、コードを書く前に手順を共有する。
