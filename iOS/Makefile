# JustLayMe iOS Makefile

.PHONY: all build test test-unit test-integration test-ui test-performance test-snapshot coverage lint clean help

# Configuration
SCHEME = JustLayMe
DESTINATION = platform=iOS Simulator,name=iPhone 15,OS=17.2
DERIVED_DATA = .build/DerivedData
RESULT_BUNDLE = TestResults

# Default target
all: lint test

# Build
build:
	@echo "Building $(SCHEME)..."
	xcodebuild build \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty

# Build for testing
build-for-testing:
	@echo "Building $(SCHEME) for testing..."
	xcodebuild build-for-testing \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty

# Run all tests
test: build-for-testing
	@echo "Running all tests..."
	xcodebuild test-without-building \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		-resultBundlePath $(RESULT_BUNDLE)/AllTests.xcresult \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty

# Run unit tests only
test-unit: build-for-testing
	@echo "Running unit tests..."
	xcodebuild test-without-building \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing:JustLayMeTests/Unit \
		-resultBundlePath $(RESULT_BUNDLE)/UnitTests.xcresult \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty

# Run integration tests only
test-integration: build-for-testing
	@echo "Running integration tests..."
	xcodebuild test-without-building \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing:JustLayMeTests/Integration \
		-resultBundlePath $(RESULT_BUNDLE)/IntegrationTests.xcresult \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty

# Run UI tests only
test-ui: build-for-testing
	@echo "Running UI tests..."
	xcodebuild test-without-building \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing:JustLayMeUITests \
		-resultBundlePath $(RESULT_BUNDLE)/UITests.xcresult \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty

# Run performance tests only
test-performance: build-for-testing
	@echo "Running performance tests..."
	xcodebuild test-without-building \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing:JustLayMeTests/Performance \
		-resultBundlePath $(RESULT_BUNDLE)/PerformanceTests.xcresult \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty

# Run snapshot tests only
test-snapshot: build-for-testing
	@echo "Running snapshot tests..."
	xcodebuild test-without-building \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing:JustLayMeSnapshotTests \
		-resultBundlePath $(RESULT_BUNDLE)/SnapshotTests.xcresult \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty

# Run tests with code coverage
coverage:
	@echo "Running tests with code coverage..."
	xcodebuild test \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		-enableCodeCoverage YES \
		-resultBundlePath $(RESULT_BUNDLE)/Coverage.xcresult \
		CODE_SIGNING_ALLOWED=NO \
		| xcpretty
	@echo "Generating coverage report..."
	xcrun xccov view --report --json $(RESULT_BUNDLE)/Coverage.xcresult > coverage.json
	@echo "Coverage report saved to coverage.json"

# Coverage report
coverage-report: coverage
	@echo "Code Coverage Summary:"
	@cat coverage.json | jq '.lineCoverage * 100 | floor / 100'

# Lint
lint:
	@echo "Running SwiftLint..."
	swiftlint lint --config .swiftlint.yml

# Lint with autocorrect
lint-fix:
	@echo "Running SwiftLint with autocorrect..."
	swiftlint lint --config .swiftlint.yml --fix

# Format code
format:
	@echo "Formatting code with SwiftFormat..."
	swiftformat . --config .swiftformat

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -rf $(DERIVED_DATA)
	rm -rf $(RESULT_BUNDLE)
	rm -rf .build
	rm -f coverage.json
	xcodebuild clean -scheme $(SCHEME) | xcpretty

# Open Xcode project
open:
	open JustLayMe.xcodeproj

# Install dependencies (if using SPM)
deps:
	swift package resolve

# Update dependencies
deps-update:
	swift package update

# Generate Xcode project from Package.swift
generate-xcodeproj:
	swift package generate-xcodeproj

# Help
help:
	@echo "JustLayMe iOS Test Suite"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build              Build the project"
	@echo "  test               Run all tests"
	@echo "  test-unit          Run unit tests only"
	@echo "  test-integration   Run integration tests only"
	@echo "  test-ui            Run UI tests only"
	@echo "  test-performance   Run performance tests only"
	@echo "  test-snapshot      Run snapshot tests only"
	@echo "  coverage           Run tests with code coverage"
	@echo "  coverage-report    Show coverage summary"
	@echo "  lint               Run SwiftLint"
	@echo "  lint-fix           Run SwiftLint with autocorrect"
	@echo "  format             Format code with SwiftFormat"
	@echo "  clean              Clean build artifacts"
	@echo "  deps               Install dependencies"
	@echo "  deps-update        Update dependencies"
	@echo "  open               Open Xcode project"
	@echo "  help               Show this help message"
