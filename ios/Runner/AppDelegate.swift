import UIKit
import Flutter
import GoogleMaps


@UIApplicationMain
GMSServices.provideAPIKey("AIzaSyAL3YGfLOU2Ihv0i26NK41MQTFfUJ_l_TY")
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
