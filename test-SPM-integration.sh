#!/bin/bash

PROJECT_NAME=TempProject

# Clean up.
rm -rf $PROJECT_NAME

mkdir -p $PROJECT_NAME && cd $PROJECT_NAME

# Create the package.
swift package init --type library

# Create the Package.swift.
echo "// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: \"TempProject\",
    defaultLocalization: \"en-US\",
    platforms: [
        .iOS(.v10)
    ],
    dependencies: [
        .package(name: \"Adyen\", path: \"../\"),
    ],
    targets: [
        .target(
            name: \"TempProject\",
            dependencies: []),
        .testTarget(
            name: \"TempProjectTests\",
            dependencies: [
                \"TempProject\",
                .product(name: \"AdyenDropIn\", package: \"Adyen\"),
                .product(name: \"AdyenWeChatPay\", package: \"Adyen\")]),
    ]
)
" > Package.swift

xcodebuild -scheme TempProject-Package -destination 'generic/platform=iOS'

xcodebuild -scheme TempProject-Package -destination 'generic/platform=iOS Simulator' ARCHS=i386

xcodebuild -scheme TempProject-Package -destination 'generic/platform=iOS Simulator' ARCHS=x86_64

# Clean up.
rm -rf $PROJECT_NAME
