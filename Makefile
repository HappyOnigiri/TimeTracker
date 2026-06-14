PROJECT := TimeTracker.xcodeproj
SCHEME := TimeTracker
DESTINATION := platform=macOS
# Developer ID が無い環境でもビルド/テストできるよう ad-hoc 署名で統一する。
SIGN_FLAGS := CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual

APP := $(SCHEME).app
BUILD_DIR := build
INSTALL_DIR := /Applications

.PHONY: ci generate lint build test install clean

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
	rm -rf $(PROJECT) $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
