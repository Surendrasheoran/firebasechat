/// Copyright (c) 2021 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import FirebaseMessaging
import OneSignalFramework

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
  static var sharedImages:[String] = []
  static var deviceTokenValue:String = ""
  static var oldEntries:[LastOnline] = []
  static var tokens:[fcmToken] = []
  static var sharedImagesCache = NSCache<NSString, UIImage>()
  var backgroundTaskID: UIBackgroundTaskIdentifier!

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    AppController.shared.configureFirebase()
    AppDelegate.sharedImagesCache.removeAllObjects()
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)

    DispatchQueue.global().asyncAfter(deadline: .now() + 15) {[weak self] in
      self?.checkLockState()
    }
    
    // Remove this method to stop OneSignal Debugging
     OneSignal.Debug.setLogLevel(.LL_VERBOSE)
     
     // OneSignal initialization
     OneSignal.initialize("1b807a7b-aa62-4d9c-8cb7-0ea4a3227403", withLaunchOptions: launchOptions)
     
     // requestPermission will show the native iOS notification permission prompt.
     // We recommend removing the following code and instead using an In-App Message to prompt for notification permission
     OneSignal.Notifications.requestPermission({ accepted in
       print("User accepted notifications: \(accepted) \(String(describing: OneSignal.User.pushSubscription.id))")
     }, fallbackToSettings: true)
     
    
    
    UNUserNotificationCenter.current().delegate = self

    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { _, _ in }
    )
    

    application.registerForRemoteNotifications()
    
    Messaging.messaging().delegate = self
    
    
    return true
  }
  
  static func sendNotificationToAll(title: String, subTitle: String, message: String){
    for token in AppDelegate.tokens {
      if(token.fcmToken != OneSignal.User.pushSubscription.id)
      {
        AppDelegate.sendPushNotification(to: token.fcmToken, title: title, subTitle: subTitle, message: message)
      }
      print("Token === \(token.fcmToken) ")
    }
  }
  
  
  static func sendPushNotification(to playerId: String,title: String, subTitle: String, message: String) {
      let headers = [
        "Accept": "application/json",
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": "Basic os_v2_app_doahu65kmjgzzdfxb2skgituapbhd3x5wouert5lv5sfhd22c7dcihqlgeegk6nlvl6hiwoarqvspaaw3h26pbfqyqsfoxaoelrmg6q"
      ]
      
      let parameters: [String: Any] = [
          "app_id": "1b807a7b-aa62-4d9c-8cb7-0ea4a3227403",
          "include_player_ids": [playerId],
          "subtitle": ["en": subTitle],
          "contents": ["en": message],
          "message": ["en": message],
          "headings": ["en": title],
          "ios_badgeType": "Increase",
          "ios_badgeCount": 1,
          "mutable_content": true ]
    
      
      let url = URL(string: "https://onesignal.com/api/v1/notifications")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.allHTTPHeaderFields = headers
      
      do {
          request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
      } catch {
          print("Error serializing JSON: \(error)")
          return
      }
      
      let session = URLSession.shared
      let task = session.dataTask(with: request) { data, response, error in
          if let error = error {
              print("Error: \(error)")
              return
          }
          
          guard let httpResponse = response as? HTTPURLResponse else {
              print("Invalid response")
              return
          }
          
          if httpResponse.statusCode == 200 {
            print("Push notification sent successfully \(httpResponse)")
          } else {
            print("Error: \(httpResponse.statusCode) ==)")
          }
      }
      
      task.resume()
  }

  
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    
   // AppDelegate.deviceTokenValue = fcmToken!
   // print("didReceiveRegistrationToken token: \(AppDelegate.deviceTokenValue)")
    //sendPushNotification(to: "0bcaaa34-7b1d-4316-be9b-91af7b97f8a4", title: "New Vechicle request", subTitle: "Service Request", message: "Regular machine services request received! For more details click here" );
//    sendPushNotification(to: "4af6bd57-58dc-455c-9621-c1f0cef35300", title: "New Vechicle request", subTitle: "Service Request", message: "Regular machine services request received! For more details click here" );
    
  //  sendPushNotification()
//    let dataDict: [String: String] = ["token": fcmToken ?? ""]
//    NotificationCenter.default.post(
//      name: Notification.Name("FCMToken"),
//      object: nil,
//      userInfo: dataDict
//    )
    // TODO: If necessary send token to application server.
    // Note: This callback is fired at each app startup and whenever a new token is generated.
  }
  
  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    
    Messaging.messaging().apnsToken = deviceToken
    //AppDelegate.deviceTokenValue = "\(String(describing: deviceToken))"
  //  print("didRegisterForRemoteNotificationsWithDeviceToken Firebase registration devicetoken: \(AppDelegate.deviceTokenValue)")

    
  }
  
  func checkLockState() {
    backgroundTaskID = UIApplication.shared.beginBackgroundTask()
    Utility.checkDeviceLockState() {
      lockState in
      self.resetifLock(lockState: lockState)
    }
  }
  
  func resetifLock(lockState: DeviceLockState)
  {
    if lockState == DeviceLockState.locked{
      AppController.shared.window.isHidden = false
      AppController.shared.show(in: AppController.shared.window)
      UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
    }
    else
    {
      checkLockState()
    }
  }
  
  func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) {
    AppController.shared.window.isHidden = false
    AppController.shared.show(in: AppController.shared.window)
  }
  
  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    AppController.shared.show(in: AppController.shared.window)
    AppController.shared.window.isHidden = true
    exit(0)
    abort()
  }
  
  func applicationWillTerminate(_ application: UIApplication) {
//    abort()
  //  exit(0)
  }
  
  func applicationWillEnterForeground(_ application: UIApplication) {
    AppController.shared.window.isHidden = false
  }
  
  func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
    AppController.shared.show(in: AppController.shared.window)
    return true
  }
    
     @objc func appMovedToBackground() {
         // do whatever event you want
       AppController.shared.loadChat()
       exit(0)
       //abort()
     }
  
  
  
  
//  func sendPushNotification() {
//      // Replace these with your actual OneSignal App ID and REST API Key
//      let appID = "1b807a7b-aa62-4d9c-8cb7-0ea4a3227403"
//      let restAPIKey = "os_v2_app_doahu65kmjgzzdfxb2skgituapbhd3x5wouert5lv5sfhd22c7dcihqlgeegk6nlvl6hiwoarqvspaaw3h26pbfqyqsfoxaoelrmg6q"
//      
//      // The player IDs of the devices you want to send the notification to
//      let playerIDs = ["0bcaaa34-7b1d-4316-be9b-91af7b97f8a4",
//                       "4af6bd57-58dc-455c-9621-c1f0cef35300"]  // Add player IDs here
//
//      // Notification content
//      let notificationContent: [String: Any] = [
//          "app_id": appID,
//          "include_player_ids": playerIDs,
//          "headings": ["en": "Hello World"],
//          "contents": ["en": "This is a test notification."],
//          "ios_sound": "default",  // Optional: Use "default" or your custom sound file name
//          "ios_badgeType": "Increase",  // Optional: Badge behavior
//          "ios_badgeCount": 1  // Optional: Badge count to set or increase by
//      ]
//      
//      // Convert notification content dictionary to JSON data
//      guard let jsonData = try? JSONSerialization.data(withJSONObject: notificationContent, options: []) else {
//          print("Error: Unable to serialize notification content to JSON.")
//          return
//      }
//    
//    // Create the dictionary based on the provided JSON payload
//    let notificationPayload: [String: Any] = [
//        "app_id": "1b807a7b-aa62-4d9c-8cb7-0ea4a3227403",
//        "target_channel": "push",
//        "headings": [
//            "en": "Vehicle service visits."
//        ],
//        "subtitle": [
//            "en": "New status is updated"
//        ],
//        "contents": [
//            "en": "New status is updated"
//        ],
//        "include_player_ids": [
//            "0bcaaa34-7b1d-4316-be9b-91af7b97f8a4",
//            "4af6bd57-58dc-455c-9621-c1f0cef35300"
//        ],
//        "include_aliases": [
//            "ExternalIds": [
//                "rest@testing.com"
//            ]
//        ],
//        "isIos": true
//    ]
//
//      // OneSignal API URL
//      let url = URL(string: "https://onesignal.com/api/v1/notifications")!
//      
//      // Set up the request with required headers and body
//      var request = URLRequest(url: url)
//      request.httpMethod = "POST"
//      request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
//      request.setValue("Basic \(restAPIKey)", forHTTPHeaderField: "Authorization")
//      request.httpBody = jsonData
//      
//      // Create a URL session and send the request
//      let task = URLSession.shared.dataTask(with: request) { data, response, error in
//          if let error = error {
//              print("Error: \(error.localizedDescription)")
//              return
//          }
//          
//          if let data = data {
//              // Convert the response data to a readable format
//              if let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
//                  print("Response: \(responseJSON)")
//              } else {
//                  print("Error: Unable to parse response.")
//              }
//          }
//      }
//      
//      // Start the network request
//      task.resume()
//  }
}
