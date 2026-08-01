# TimeTracker

[日本語](README.ja.md)

TimeTracker is a macOS menu bar app for tracking time by project.

## Screenshots

<img src="Documentation/Images/en/dashboard.png" alt="Dashboard showing tracked time for the month" width="720">

<img src="Documentation/Images/en/menu-bar.png" alt="Menu bar window for selecting a project and starting a timer" width="640">

- macOS 14 or later
- All data is stored locally

## Features

- Start and stop timers from the menu bar, track multiple projects concurrently, or start from an earlier time.
- Automatically stop running timers after a period of inactivity and exclude idle time from your records.
- Add work notes to records and edit them from the list or monthly timeline.
- Review monthly tracked time and export reports as CSV files.
- Manage projects and configure idle detection, launch at login, display language, and other preferences.

## Privacy

Your records stay on your Mac and are never sent elsewhere. Idle detection does not capture your input; it only checks the time since the last keyboard or mouse event. Accessibility and Input Monitoring permissions are not required.

## Installation

Xcode and XcodeGen are required. Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

Clone the repository and install the app in `/Applications`:

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
