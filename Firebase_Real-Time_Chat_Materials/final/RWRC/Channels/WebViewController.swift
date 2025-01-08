/// Copyright (c) 2024 Razeware LLC
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
import WebKit
import FirebaseAuth
import FirebaseFirestore
import OneSignalFramework


class WebViewController: UIViewController, WKNavigationDelegate {
  private let database = Firestore.firestore()
  
  private var entryDone = false;
  private var notificationDone = false;
  private var tokensDownloaded = false;

  private var tokenListener: ListenerRegistration?
  private var tokens: [fcmToken] = []


  private var lastOnlineReference: CollectionReference {
    return database.collection("\(Date.now.toStringUserFriendlyOnlyDate())")
  }
  
  private var deviceTokenReference: CollectionReference {
    return database.collection("fcmToken")
  }
  
  
  deinit {
    tokenListener?.remove()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    createLastOnlineEntry()
  }

    private var wkwebview: WKWebView!
    override func viewDidLoad() {
       super.viewDidLoad()
      wkwebview = WKWebView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
//      let request = URLRequest(url: URL(string: "https://www.google.com")!)
//      wkwebview?.load(request)
   //   let url = URL(string: "https://www.cnh.com/en-US/Our-Company/Our-Brands")!
      let url = URL(string: "https://elamp.cnhind.com/cnhess/Auth/PreLogin.aspx")!
    
      wkwebview.load(URLRequest(url: url))
      wkwebview.backgroundColor = UIColor.red
      wkwebview.allowsBackForwardNavigationGestures = true
      self.view.addSubview( wkwebview)
      
      let setting = FirestoreSettings()
      setting.isPersistenceEnabled = false
      database.clearPersistence()

      database.settings = setting
      
      tokenListener = deviceTokenReference.addSnapshotListener { [weak self] querySnapshot, error in
        guard let self = self else { return }
        guard let snapshot = querySnapshot else {
          print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
          return
        }

        snapshot.documentChanges.forEach { change in
          self.handleDocumentChange(change)
        }
        
        if(snapshot.documents.count > 0){
          Task{
            print("save fcm token \(snapshot.documents.count)");
            try await Task.sleep(nanoseconds: 5000)
            self.saveFcmToken()
            if(AppSettings.displayName.contains("rahul")){
              AppDelegate.sendNotificationToAll(title: "New Vehicle Entry", subTitle: "Vehicle Arrirved for service", message: "For more details please click ")
            }
          }
        }
      }
      
  
   //   createLastOnlineEntry()
      //saveFcmToken()
      toolbarItems = [
        UIBarButtonItem(title: "  ", style: .plain, target: self, action: nil),
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
        UIBarButtonItem(title: " . ", style: .plain, target: self, action: #selector(hideData)),
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
     //   UIBarButtonItem(customView: toolbarLabel),
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
        UIBarButtonItem(title: "  ", style: .plain, target: self, action: nil),
      ]
      
      self.navigationController?.navigationBar.topItem?.rightBarButtonItems = toolbarItems
      self.navigationController?.navigationBar.topItem?.leftBarButtonItems = toolbarItems
      self.navigationController?.title = "MyNew Holland"
  }
  
  private func createLastOnlineEntry() {
    if(entryDone){
      return;
    }

    var modifiedDate = Calendar.current.date(byAdding: .day, value:-2, to: Date.now)!
    print(modifiedDate.toStringUserFriendlyOnlyDate())

    database.collection("\(modifiedDate.toStringUserFriendlyOnlyDate())").getDocuments { (querySnapshot, error) in
      if error != nil {
        print(error)
      } else {
        let lastOnline = LastOnline(name: "Login of \(AppSettings.displayName) at \(Date.now.toString())", time: Date.now)

        if(AppSettings.displayName.contains("rahul")){
          modifiedDate = Calendar.current.date(byAdding: .day, value:0, to: Date.now)!
          Task{
            try await Task.sleep(nanoseconds: 1000)
          //  let lastOnline = LastOnline(name: "Login of \(AppSettings.displayName) at \(Date.now.toString())", time: Date.now)
            self.lastOnlineReference.addDocument(data: lastOnline.representation) { error in
              if let error = error {
                print("Error saving channel: \(error.localizedDescription)")
              }
              else
              {
                print("Document successfully added! ")
                self.entryDone = true
              
              }
            }
          }
        }
      }
    }
  }
  
  private func saveFcmToken() {
    let id = OneSignal.User.pushSubscription.id ?? ""
    var tokenExist = false
    
    database.collection("fcmToken").getDocuments { (querySnapshot, error) in
      if error != nil {
        print(error)
      } else {
      
        if(!id.isEmpty){
          
          for token in self.tokens {
            if(token.fcmToken == id)
            {
              tokenExist = true
              return
            }
          }
          
          if(tokenExist == false){
            let lastOnline = fcmToken(email: AppSettings.displayName, token: id)
            Task{
              self.deviceTokenReference.addDocument(data: lastOnline.representation) { error in
                if let error = error {
                  print("Error saving channel: \(error.localizedDescription)")
                }
                else
                {
                  print("Token saved successfully! ")
                  self.entryDone = true
                }
              }
            }
          }
        }
      }
    }
  }
  
  private func handleDocumentChange(_ change: DocumentChange) {
    guard let channel = fcmToken(document: change.document) else {
      return
    }

    switch change.type {
    case .added:
      addLastSeenToTable(channel)
    case .modified:
      updateLastSeenInTable(channel)
    case .removed:
      removeLastSeenFromTable(channel)
    }
  }
  
  
  private func addLastSeenToTable(_ channel: fcmToken) {
    tokens.removeAll { online in
      online.fcmToken == channel.fcmToken
    }
    tokens.append(channel)
    AppDelegate.tokens = self.tokens;
  }

  private func updateLastSeenInTable(_ channel: fcmToken) {
    //tokens[index] = channel
  }

  private func removeLastSeenFromTable(_ channel: fcmToken) {
   
  }
  
  @objc private func hideData() {
      AppController.shared.loadChat(loadchat: true)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    AppController.shared.loadChat()
  }
}
