PROJECT := TimeTracker.xcodeproj
SCHEME := TimeTracker
DESTINATION := platform=macOS
# Developer ID が無い環境でもビルド/テストできるよう ad-hoc 署名で統一する。
SIGN_FLAGS := CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual

.PHONY: ci generate lint build test clean

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

## clean: 生成物を削除
clean:
	rm -rf $(PROJECT)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
