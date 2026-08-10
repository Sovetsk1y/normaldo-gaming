import UIKit
import Flutter

@objc class DefferingSystemGesturesFlutterController: FlutterViewController {
    override var prefersHomeIndicatorAutoHidden: Bool {
      return false
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
      return UIRectEdge.bottom
    }
}

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    var flutterViewController: FlutterViewController?
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
//      self.flutterViewController = DefferingSystemGesturesFlutterController()
//      self.window = UIWindow.init(frame: UIScreen.main.bounds)
//      self.window.rootViewController = UINavigationController.init(rootViewController: self.flutterViewController!)
//      self.window.makeKeyAndVisible()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
