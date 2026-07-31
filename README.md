# TimeTracker

TimeTracker は、macOS のメニューバーからプロジェクトごとの作業時間を記録するローカル完結型のタイムトラッカーです。計測、記録の修正、月次レポート、CSV 出力までを 1 つのアプリで行えます。

- 対応 OS: macOS 14 以降
- UI: 日本語
- ローカル保存

## 主な機能

### メニューバーから計測

- プロジェクト名をクリックしてタイマーを開始・停止
- 計測中の経過時間を秒単位で表示
- 複数プロジェクトの同時計測に対応（設定で無効化可能）
- 5・10・15 分前、または任意の過去日時から計測を開始
- 計測中のプロジェクトカラーをメニューバーアイコンに反映

### アイドル検知と作業内容

- キーボードやマウスの入力が一定時間なければ、離席開始時刻まで遡って全タイマーを自動停止
- 自動停止後の確認画面から計測を再開
- 停止時に複数の「作業内容」をタグとして記録
- 最近使った作業内容を候補から再利用
- 既存の作業内容を全期間の記録に対して一括変更

### 記録の確認・編集

「記録」画面では、月とプロジェクトで絞り込みながら、リストまたはタイムラインでログを確認できます。

- 記録の追加、編集、複製、削除
- 日付、開始・終了時刻、プロジェクト、作業内容の修正
- タイムライン上でブロックをドラッグして日時を移動
- ブロックの左右端をドラッグして開始・終了時刻を変更
- 空いている時間帯の右クリックから 1 時間の記録を追加
- ボタン、ピンチ操作、`Command` + スクロールでタイムラインを拡大・縮小
- PC がアクティブだった時間帯をタイムラインの背景に表示
- 作業内容が未入力のブロックを強調表示

ドラッグ時の丸め幅は 5・10・15・30 分から選べます。計測中のログは誤操作を防ぐため、停止するまで読み取り専用です。

### ダッシュボードと CSV

月単位・プロジェクト単位で絞り込み、次の集計を Swift Charts で表示します。

- プロジェクト別の合計稼働時間
- 1 日ごとの稼働時間推移
- 作業内容別の稼働時間

表示中の月とプロジェクトを対象に、次の CSV を保存できます。

| 種類 | 内容 |
| --- | --- |
| 時間別 | プロジェクト、開始・終了日時、秒数、作業内容を記録ごとに出力 |
| 作業内容別 | 作業内容ごとの秒数・時間数を出力 |
| 日付別 | JST 基準で各日の稼働時間と作業内容を出力（稼働のない日も含む） |

1 つの記録に複数の作業内容がある場合、作業内容別集計では時間を均等に配分します。CSV は表計算ソフトでの数式実行を防ぐため、危険な先頭文字を無害化して出力します。

### プロジェクトと設定

- プロジェクトの追加、名前・テーマカラーの編集、削除
- アイドル検知の有効化、判定時間、自動停止モーダルの設定
- 複数プロジェクトの同時計測の許可
- 停止時に作業内容の入力を促すかどうかの設定
- タイムラインのスナップ単位と未入力ブロック表示の設定
- Mac ログイン時の自動起動

プロジェクトを削除すると、そのプロジェクトに属する記録も削除されます。この操作は取り消せません。

## プライバシーと権限

TimeTracker のアプリ本体に外部サービス連携はなく、プロジェクト、記録、PC のアクティブ時間はすべて端末内に保存されます。

- App Sandbox を有効化
- アイドル検知には `CGEventSource.secondsSinceLastEventType` を使用
- 入力内容そのものは取得せず、最後のキーボード・マウス入力からの経過時間だけを参照
- アクセシビリティ権限や入力監視権限は不要
- CSV は `NSSavePanel` でユーザーが選んだ保存先にのみ書き込み

サンドボックスを解除したり、追加のプライバシー権限を付与したりする必要はありません。

## 必要環境

- macOS 14 以降
- Xcode（使用バージョンは `.github/workflows/ci.yml` を参照）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [SwiftLint](https://github.com/realm/SwiftLint)

開発ツールは Homebrew でインストールできます。

```sh
brew install xcodegen swiftlint
```

外部の Swift Package 依存関係はありません。

## ビルドとインストール

```sh
git clone https://github.com/HappyOnigiri/TimeTracker.git
cd TimeTracker

make generate   # project.yml から TimeTracker.xcodeproj を生成
make build      # ad-hoc 署名で Debug ビルド
make install    # Release ビルドを /Applications に配置
```

`make install` は既存の `/Applications/TimeTracker.app` を置き換えます。環境によっては `/Applications` への書き込み権限が必要です。

Xcode で開く場合は、`make generate` の後に `TimeTracker.xcodeproj` を開いてください。プロジェクトファイルは `project.yml` から生成されるため、Git では管理していません。

## 開発コマンド

| コマンド | 内容 |
| --- | --- |
| `make generate` | XcodeGen で Xcode プロジェクトを生成 |
| `make lint` | SwiftLint を strict モードで実行 |
| `make build` | ad-hoc 署名でアプリをビルド |
| `make test` | ユニットテストを実行 |
| `make ci` | lint、build、test を順に実行 |
| `make install` | Release ビルドを `/Applications` に配置 |
| `make clean` | 生成した Xcode プロジェクトとビルド成果物を削除 |

変更を送る前に、次を実行してください。

```sh
make test
make ci
```

Pull Request の CI も macOS ランナー上で `make ci` を実行します。

## コードベースの構成

```text
Sources/
├── TimeTrackerApp.swift     # MenuBarExtra、メインウィンドウ、SwiftData の初期化
├── Models/                  # Project、TimeLog、ActiveSession
├── Core/                    # タイマー、集計、CSV、設定、編集ロジック
└── Views/                   # メニューバー、記録、ダッシュボード、設定の SwiftUI 画面
Tests/                       # Swift Testing によるユニットテスト
project.yml                 # XcodeGen のプロジェクト定義
Makefile                    # ローカル開発・CI 用コマンド
```

### 実装の入口

| 関心ごと | 主なファイル |
| --- | --- |
| アプリ構成・データストア | `Sources/TimeTrackerApp.swift` |
| タイマー開始・停止、アイドル自動停止 | `Sources/Core/TimerEngine.swift` |
| PC アクティブ時間の記録 | `Sources/Core/ActiveTimeTracker.swift` |
| 記録・プロジェクト・アクティブ時間 | `Sources/Models/TimeLog.swift`、`Project.swift`、`ActiveSession.swift` |
| 月次集計 | `Sources/Core/ReportAggregator.swift` |
| CSV 生成・保存 | `Sources/Core/CSVExporter.swift`、`CSVExportService.swift` |
| メニューバー UI | `Sources/Views/MenuBarContentView.swift`、`MenuBarProjectRow.swift` |
| 記録のリスト／タイムライン | `Sources/Views/RecordsView.swift`、`MonthTimelineView.swift` |
| ダッシュボード | `Sources/Views/DashboardView.swift` |
| 設定 | `Sources/Core/AppSettings.swift`、`Sources/Views/SettingsView.swift` |

SwiftUI の画面が SwiftData のモデルを `@Query` で参照し、状態遷移や再利用する処理を `Core` のサービス・純粋ロジックへ分けた、macOS アプリ向けの軽量なレイヤー構成です。AppKit はメニューバー、モーダルパネル、保存パネルなど macOS 固有の処理に限定して使用しています。

## データモデルと動作上の注意

- `Project`: プロジェクト名、テーマカラー、表示順を保持。`TimeLog` を所有します。
- `TimeLog`: 1 回の計測区間。終了時刻がない状態を「計測中」として表し、複数の作業内容を保持します。
- `ActiveSession`: PC がアクティブだった区間。タイムライン背景の表示に使います。
- 異常終了などで未完了のまま残った計測ログは、次回起動時に開始時刻で閉じ、実際に確認できない時間を加算しません。
- アクティブ時間の未完了セッションは、次回起動時に最後の入力時刻で閉じます。
- 日付別 CSV は実行環境のタイムゾーンにかかわらず JST の日付境界で集計します。

## テスト

テストは Swift Testing を中心に、次の領域をカバーしています。

- タイマーの開始・停止、同時計測、アイドル停止、過去時刻からの開始
- 月境界・日付境界を含むレポート集計
- CSV の期間クリップ、クォート、数式インジェクション対策
- 時刻入力のパースと反映
- 作業内容の候補生成と一括変更
- タイムラインのレイアウト、ドラッグ判定、スナップ表示
- カラー変換とアイドル時間の取得

## コントリビュート

不具合や機能提案は [Issues](https://github.com/HappyOnigiri/TimeTracker/issues) へ、変更は Pull Request で送ってください。PR を作成する前に `make ci` が通ることを確認してください。

## ライセンス

[MIT License](LICENSE) の下で公開しています。
