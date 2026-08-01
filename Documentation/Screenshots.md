# README 用スクリーンショット

通常版とは別の `TimeTracker Sample.app` を使って画面を確認できます。アプリ識別子と保存領域は通常版から分離され、起動するたびにサンプルデータへ戻ります。

```sh
make sample-install
```

インストール先は `/Applications/TimeTracker Sample.app` です。通常版の `TimeTracker.app` は変更しません。

README 用の英語・日本語ダッシュボード画像は、アプリやウィンドウを開かずに生成できます。

```sh
make screenshots
```

生成先は次のファイルです。

- `Documentation/Images/en/dashboard.png`
- `Documentation/Images/ja/dashboard.png`

メニューバー画像は、macOS のメニューバーを含めて手動で撮影します。Sample アプリの設定で表示言語を切り替え、再起動するとサンプルデータも選択言語に切り替わります。

- `Documentation/Images/en/menu-bar.png`
- `Documentation/Images/ja/menu-bar.png`

これらは `make screenshots` では変更されません。更新する場合は、Sample アプリを対象言語で表示して撮影してください。
