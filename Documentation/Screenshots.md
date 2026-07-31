# README 用スクリーンショット

通常版とは別の `TimeTracker Sample.app` を使って画面を確認できます。アプリ識別子と保存領域は通常版から分離され、起動するたびにサンプルデータへ戻ります。

```sh
make sample-install
```

インストール先は `/Applications/TimeTracker Sample.app` です。通常版の `TimeTracker.app` は変更しません。

README 用の PNG は、アプリやウィンドウを開かずに生成できます。

```sh
make screenshots
```

生成先は次の2ファイルです。

- `Documentation/Images/dashboard.png`
- `Documentation/Images/menu-bar.png`
