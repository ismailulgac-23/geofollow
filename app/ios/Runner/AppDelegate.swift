import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate, MessagingDelegate {
  let locationManager = CLLocationManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Google Maps API Key from Info.plist
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_KEY") as? String {
      GMSServices.provideAPIKey(apiKey)
    }

    // Native Arka Plan Konum Ayarları (Survival Mode)
    locationManager.delegate = self
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    
    // Uygulama kapalı olsa bile (Terminated) önemli hareketlerde uyandırılmasını sağlar
    locationManager.startMonitoringSignificantLocationChanges()

    // Firebase Messaging
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()
    Messaging.messaging().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // FCM Token callback (optional but good for debugging)
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
  }
}
