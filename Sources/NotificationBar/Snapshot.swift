import AppKit
import SwiftUI

@MainActor
func runSnapshot(outputPath: String) {
    let dark = ProcessInfo.processInfo.environment["NOTIFBAR_DARK"] != nil
    Task { @MainActor in
        let store = Store()
        await store.refresh()
        let background = dark ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color(nsColor: .windowBackgroundColor)
        let view = ContentView(store: store, isSnapshot: true)
            .background(background)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("snapshot render failed\n".utf8))
            exit(1)
        }
        do {
            try png.write(to: URL(fileURLWithPath: outputPath))
            print("wrote \(outputPath)")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
            exit(1)
        }
    }
    RunLoop.main.run()
}
