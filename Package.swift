// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InkLayer",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "InkLayer",
            path: ".",
            exclude: ["build_app.sh", "README.md", "Build InkLayer.command"],
            sources: [
                "main.swift", "AppDelegate.swift", "AnnotationController.swift",
                "CanvasView.swift", "Geometry.swift", "HotKeys.swift",
                "Models.swift", "ToolbarPanel.swift"
            ],
            swiftSettings: [.swiftLanguageVersion(.v5)]
        )
    ]
)
