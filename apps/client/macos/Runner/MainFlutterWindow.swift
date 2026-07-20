import Cocoa
import FlutterMacOS

private let ordinWarmWhite = NSColor(
  srgbRed: 252.0 / 255.0,
  green: 248.0 / 255.0,
  blue: 238.0 / 255.0,
  alpha: 1.0
)

private final class OrdinLaunchViewController: NSViewController {
  init(flutterViewController: FlutterViewController) {
    self.flutterViewController = flutterViewController
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let flutterViewController: FlutterViewController

  override func loadView() {
    let rootView = NSView()
    rootView.wantsLayer = true
    rootView.layer?.backgroundColor = ordinWarmWhite.cgColor

    let launchMark = NSImageView()
    launchMark.image = NSImage(named: NSImage.Name("OrdinLaunchMark"))
    launchMark.imageScaling = .scaleProportionallyUpOrDown
    launchMark.translatesAutoresizingMaskIntoConstraints = false
    rootView.addSubview(launchMark)

    addChild(flutterViewController)
    let flutterView = flutterViewController.view
    flutterView.translatesAutoresizingMaskIntoConstraints = false
    rootView.addSubview(flutterView)

    NSLayoutConstraint.activate([
      launchMark.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
      launchMark.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
      launchMark.widthAnchor.constraint(equalToConstant: 112),
      launchMark.heightAnchor.constraint(equalToConstant: 112),
      flutterView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      flutterView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      flutterView.topAnchor.constraint(equalTo: rootView.topAnchor),
      flutterView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])
    view = rootView
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = .clear
    backgroundColor = ordinWarmWhite

    let windowFrame = self.frame
    self.contentViewController = OrdinLaunchViewController(
      flutterViewController: flutterViewController
    )
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
