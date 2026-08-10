# TimeTracker

[日本語](README.ja.md) | [简体中文](README.zh-CN.md)

TimeTracker is a macOS menu bar app for tracking time by project.

## Screenshots

<img src="Documentation/Images/en/dashboard.png" alt="Dashboard showing tracked time for the month" width="720">

<img src="Documentation/Images/en/menu-bar.png" alt="Menu bar window for selecting a project and starting a timer" width="378">

- macOS 14 or later
- All data is stored locally

## Features

- Start and stop timers from the menu bar, track multiple projects concurrently, or start from an earlier time.
- Automatically stop running timers after a period of inactivity and exclude idle time from your records.
- Add work notes to records and edit them from the list or monthly timeline. Work notes can be linked to multiple projects; inputs suggest recently used notes for the current project, with **Show All** available for the full catalog.
- Manage work note text and linked projects from the Records screen, including consistent updates to past records when a note is renamed.
- Review monthly tracked time and export reports as CSV files.
- Manage projects and configure idle detection, launch at login, display language, and other preferences.

## Privacy

Your records stay on your Mac and are never sent elsewhere. Idle detection does not capture your input; it only checks the time since the last keyboard or mouse event. Accessibility and Input Monitoring permissions are not required.

## Installation

Download `TimeTracker-vX.Y.Z.zip` from the [latest release](https://github.com/HappyOnigiri/TimeTracker/releases/latest), extract it, and move `TimeTracker.app` to `/Applications`.

The app uses an ad-hoc signature and is not notarized by Apple. The first time you open it, macOS may block it because the developer cannot be verified. After trying to open the app, go to **System Settings > Privacy & Security**, scroll down to Security, and click **Open Anyway**. See [Apple's instructions for opening an app from an unknown developer](https://support.apple.com/guide/mac-help/mh40616/mac).

### Build from source

Building from source requires Xcode and XcodeGen. Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

Clone the repository and build the app in `/Applications`:

```sh
git clone https://github.com/HappyOnigiri/TimeTracker.git
cd TimeTracker
make install
```

`make install` replaces an existing `/Applications/TimeTracker.app`.

## Contributing

Please use [Issues](https://github.com/HappyOnigiri/TimeTracker/issues) for bug reports and feature requests, and submit changes as pull requests.

Before opening a pull request, install SwiftLint and verify that `make ci` succeeds:

```sh
brew install swiftlint
make ci
```

## License

Released under the [MIT License](LICENSE).
