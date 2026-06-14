# TimeTracker

macOS のメニューバーに常駐するシンプルなタイムトラッキングアプリです。プロジェクトごとに作業時間を記録し、日々の活動を手軽に振り返ることができます。Swift / SwiftUI で書かれています。

## 特徴

- 🪶 **メニューバー常駐** — ウィンドウを占有せず、ワンクリックで計測を開始 / 停止
- 📊 **プロジェクト別の集計** — 作業時間をプロジェクトごとに記録・可視化（Swift Charts）
- 😴 **アイドル検知** — 離席を自動で検知し、無駄な計測を防止
- 📤 **CSV エクスポート** — 記録したデータを書き出して自由に分析
- 🔒 **プライバシー重視** — App Sandbox 有効、データはすべてローカルに保存

## 必要環境

- macOS 14 以降
- Xcode 26 以降
- `xcodegen`, `swiftlint`

```sh
brew install xcodegen swiftlint
```

## インストール / ビルド

```sh
git clone https://github.com/HappyOnigiri/project-timer.git
cd project-timer

make generate   # project.yml から TimeTracker.xcodeproj を生成
make build      # ad-hoc 署名でビルド
make install    # ビルドして /Applications にインストール
```

Xcode で開く場合は `make generate` 後に `TimeTracker.xcodeproj` を開いてください。

### 開発向けコマンド

```sh
make test   # ユニットテスト
make ci     # lint + build + test
```

## 設計メモ

- **プロジェクト定義**: `project.yml`（xcodegen）。`.xcodeproj` は生成物のため Git 管理外。
- **データ永続化**: SwiftData。
- **グラフ**: Swift Charts。
- **App Sandbox は有効のまま運用する。**
- **アイドル検知**: `CGEventSourceSecondsSinceLastEventType` を使用する。これは HID の
  アイドル秒数を読むだけで、イベントタップと異なり**アクセシビリティ（入力監視）権限は不要**。
  App Sandbox 内でも権限ダイアログなしに動作する。
- **CSV 出力**: `NSSavePanel` でユーザーが選んだ場所にのみ書き込む
  （`com.apple.security.files.user-selected.read-write`）。サンドボックスを外さない。
  プロジェクト名は CSV インジェクション（数式実行）を防ぐため出力時に無害化する。

> サンドボックス解除やアクセシビリティ権限の付与は不要。

## コントリビュート

バグ報告・機能提案・プルリクエストを歓迎します！🎉

- 不具合や要望があれば気軽に [Issue](https://github.com/HappyOnigiri/project-timer/issues) を立ててください。
- コードを変更する場合は、PR を送る前に `make ci` が通ることを確認してください。

## ライセンス

[MIT License](LICENSE) の下で公開しています。
