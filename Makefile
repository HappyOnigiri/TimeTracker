PROJECT := TimeTracker.xcodeproj
SCHEME := TimeTracker
SAMPLE_SCHEME := TimeTrackerSample
SCREENSHOT_SCHEME := ReadmeScreenshotGenerator
DESTINATION := platform=macOS
# Developer ID が無い環境でもビルド/テストできるよう ad-hoc 署名で統一する。
SIGN_FLAGS := CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual

APP := $(SCHEME).app
SAMPLE_APP := TimeTracker Sample.app
BUILD_DIR := build
SAMPLE_BUILD_DIR := build-sample
SCREENSHOT_BUILD_DIR := build-screenshots
INSTALL_DIR := /Applications

.PHONY: ci generate lint build test screenshots sample-build sample-install install clean

## ci: lint + build + test を順に実行する
ci: lint build test

## generate: project.yml から Xcode プロジェクトを生成する
generate:
	xcodegen generate

## lint: SwiftLint による静的解析
lint:
	swiftlint lint --strict

## build: アプリをビルド（ad-hoc 署名）
build: generate
	xcodebuild build \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' $(SIGN_FLAGS)

## test: ユニットテストを実行
test: generate
	xcodebuild test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' $(SIGN_FLAGS)

## screenshots: README 用の画面をアプリを起動せずに生成する
screenshots: generate
	xcodebuild build \
		-project $(PROJECT) -scheme $(SCREENSHOT_SCHEME) \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(SCREENSHOT_BUILD_DIR) \
		CODE_SIGNING_ALLOWED=NO
	xcrun xcstringstool compile \
		--output-directory "$(SCREENSHOT_BUILD_DIR)/Build/Products/Release" \
		Sources/Localizable.xcstrings
	"$(SCREENSHOT_BUILD_DIR)/Build/Products/Release/$(SCREENSHOT_SCHEME)" \
		"$(CURDIR)/Documentation/Images"

## sample-build: 通常版と保存領域を分離したサンプルアプリをビルドする
sample-build: generate
	xcodebuild build \
		-project $(PROJECT) -scheme $(SAMPLE_SCHEME) \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(SAMPLE_BUILD_DIR) \
		$(SIGN_FLAGS)

## sample-install: サンプルアプリだけを /Applications に配置する
sample-install: sample-build
	rm -rf "$(INSTALL_DIR)/$(SAMPLE_APP)"
	cp -R "$(SAMPLE_BUILD_DIR)/Build/Products/Release/$(SAMPLE_APP)" "$(INSTALL_DIR)/"
	@echo "Installed: $(INSTALL_DIR)/$(SAMPLE_APP)"

## install: Release ビルドして /Applications に配置する（Xcode GUI 不要）
install: generate
	xcodebuild build \
		-project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(BUILD_DIR) \
		$(SIGN_FLAGS)
	rm -rf "$(INSTALL_DIR)/$(APP)"
	cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP)" "$(INSTALL_DIR)/"
	@echo "Installed: $(INSTALL_DIR)/$(APP)"

## clean: 生成物を削除
clean:
	rm -rf $(PROJECT) $(BUILD_DIR) $(SAMPLE_BUILD_DIR) $(SCREENSHOT_BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
