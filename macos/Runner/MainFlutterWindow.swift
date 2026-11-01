import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "Cutline"
    // Same dark colour as the app, so the window never flashes white
    // while Flutter starts.
    let background = NSColor(red: 0.08, green: 0.07, blue: 0.09, alpha: 1)
    self.backgroundColor = background
    flutterViewController.backgroundColor = background
    self.contentMinSize = NSSize(width: 1000, height: 640)
    self.setContentSize(NSSize(width: 1280, height: 800))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
