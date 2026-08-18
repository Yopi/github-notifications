import AppKit

MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
        runSnapshot(outputPath: arguments[index + 1])
    } else {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
