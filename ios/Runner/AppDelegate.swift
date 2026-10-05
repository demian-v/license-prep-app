import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    self.launchOptions = launchOptions
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    replayLaunchForMessaging(engineBridge.pluginRegistry)
  }

  // TEMPORARY (instructors P5, 2026-10-05). firebase_messaging 16.0.0 does all
  // of its iOS setup (app-delegate proxy, notification-centre delegate,
  // registerForRemoteNotifications) when it observes didFinishLaunching. With
  // the implicit (UIScene) engine plugins register after that notification
  // has fired, so it never ran: permission was granted but no APNs token, so
  // no FCM token. Fixed upstream in 16.7.0 (flutterfire #18620), which needs
  // the whole Firebase stack upgraded (firebase_core 4.0 -> 4.14). Hand the
  // plugin the launch it missed; delete this with that upgrade.
  private func replayLaunchForMessaging(_ registry: FlutterPluginRegistry) {
    let selector = NSSelectorFromString("application_onDidFinishLaunchingNotification:")
    guard let plugin = registry.valuePublished(byPlugin: "FLTFirebaseMessagingPlugin") as? NSObject,
          plugin.responds(to: selector) else { return }
    var userInfo: [AnyHashable: Any] = [:]
    launchOptions?.forEach { userInfo[$0.key.rawValue] = $0.value }
    let launch = NSNotification(
      name: UIApplication.didFinishLaunchingNotification, object: UIApplication.shared, userInfo: userInfo)
    plugin.perform(selector, with: launch)
  }
}
