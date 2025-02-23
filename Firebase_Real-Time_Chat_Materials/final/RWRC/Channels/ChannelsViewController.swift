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
import FirebaseAuth
import FirebaseFirestore

final class ChannelsViewController: UITableViewController {
  private let toolbarLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.font = UIFont.systemFont(ofSize: 15)
    return label
  }()

  private let channelCellIdentifier = "channelCell"
  private var currentChannelAlertController: UIAlertController?

  var counter = 0
  var dateCounter = 1
  private let database = Firestore.firestore()
  private var channelReference: CollectionReference {
    return database.collection("channels")
  }
  
  private var lastOnlineReference: CollectionReference {
    let doc = "\(Date.now.toStringUserFriendlyOnlyDate())"
    return database.collection(doc)
  }
  
  private var yesterdayLastOnlineReference: CollectionReference {
    let doc = "\(Date.now.adding(day: -dateCounter).toStringUserFriendlyOnlyDate())"
    return database.collection(doc)
  }


  private var channels: [Channel] = []
  private var lastOnline: [LastOnline] = []
  private var channelListener: ListenerRegistration?
  private var lastSeenListener: ListenerRegistration?
  private var yesterdayLastSeenListener: ListenerRegistration?

  private var showChannels = true
  
  private let currentUser: User

  deinit {
    channelListener?.remove()
    lastSeenListener?.remove()
    yesterdayLastSeenListener?.remove()
  }

  init(currentUser: User) {
    self.currentUser = currentUser
    super.init(style: .grouped)

    title = "Welcome CNHi"
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    clearsSelectionOnViewWillAppear = true
  //  AppController.shared.window.isHidden = false

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: channelCellIdentifier)

    let notificationCenter = NotificationCenter.default
       notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    
    
    toolbarItems = [
      UIBarButtonItem(title: "--", style: .plain, target: self, action: #selector(signOut)),
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(title: ".", style: .plain, target: self, action: #selector(hideData)),
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
   //   UIBarButtonItem(customView: toolbarLabel),
      UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(showLastOnline)),

      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonPressed))
    ]
    
    
    if(!AppSettings.displayName.isEmpty){
      toolbarLabel.text = AppSettings.displayName
    }
    
    //yesterdayLastOnlineReference.order(by: "time", descending:true)

    DispatchQueue.global(qos: .userInteractive).async {

      self.lastSeenListener = self.lastOnlineReference.addSnapshotListener { [weak self] querySnapshot, error in
        guard let self = self else { return }
        guard let snapshot = querySnapshot else {
          print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
          
          loadYesterday()
          
          return
        }
        
        snapshot.documentChanges.forEach { change in
          self.handleLastOnlineDocumentChange(change)
        }
        
        if(snapshot.documentChanges.count == 0)
        {
          let fakeOnline = LastOnline(name: "--- \(Date.now.toReadableString())  \(Date.now.toStringUserFriendlyOnlyDate())", time: Date.now)
          lastOnline.append(fakeOnline)
          
          loadYesterday()
        }
      }
    }
    
    channelListener = channelReference.addSnapshotListener { [weak self] querySnapshot, error in
      guard let self = self else { return }
      guard let snapshot = querySnapshot else {
        print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
        return
      }

      snapshot.documentChanges.forEach { change in
        self.handleDocumentChange(change)
      }
    }
  }
  
  func loadYesterday()
  {
    yesterdayLastSeenListener = yesterdayLastOnlineReference.addSnapshotListener { [weak self] querySnapshot, error in
      guard let self = self else { return }
      guard let snapshot = querySnapshot else {
        print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
        return
      }

      snapshot.documentChanges.forEach { change in
        self.handleLastOnlineDocumentChange(change)
      }
      
      if(snapshot.documentChanges.count == 0)
      {
      
        let fakeOnline = LastOnline(name: "--- \(Date.now.adding(day: -dateCounter).toReadableString())  \(Date.now.adding(day: -dateCounter).toStringUserFriendlyOnlyDate())", time: Date.now.adding(day: -dateCounter))
        lastOnline.append(fakeOnline)
        lastOnline =  lastOnline.sorted(by: { $0.time.compare($1.time) == .orderedDescending })
        lastOnline = lastOnline.sorted(by: {$0.time > $1.time})

        dateCounter+=1
        DispatchQueue.main.async {
          // Update the UI on the main thread
          self.tableView.reloadData()
        }
        loadYesterday()
      }
    }
  }
  
  @objc func appMovedToBackground() {
      // do whatever event you want
    AppController.shared.show(in: AppController.shared.window)
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
//    if(AppController.shared.loadChat == false){
//      AppController.shared.window.isHidden = true
//      navigationController?.isToolbarHidden = true
//      navigationController?.popToRootViewController(animated: true)
//    }
  }
  

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isToolbarHidden = false
    tableView.isHidden = true
    AppController.shared.loadChat = true
    counter = 0
  }
  
  @objc private func showLastOnline() {
    showChannels = !showChannels
    tableView.isHidden = showChannels
    tableView.reloadData()
  }

  // MARK: - Actions
  @objc private func signOut() {
//    let alertController = UIAlertController(
//      title: nil,
//      message: "Are you sure you want to sign out?",
//      preferredStyle: .alert)
//    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
//    alertController.addAction(cancelAction)
//
//    let signOutAction = UIAlertAction(
//      title: "Sign Out",
//      style: .destructive) { _ in
//      do {
//        try Auth.auth().signOut()
//      } catch {
//        print("Error signing out: \(error.localizedDescription)")
//      }
//    }
//    alertController.addAction(signOutAction)
    do {
      database.clearPersistence()
      Firestore.firestore(database: "channels").clearPersistence()
      Firestore.firestore(database: "lastOnline_\(AppSettings.displayName)").clearPersistence()

      try Auth.auth().signOut()
    } catch {
      print("Error signing out: \(error.localizedDescription)")
    }
//    present(alertController, animated: true)
  }
  
  @objc private func hideData() {
    if (counter > 8){
      tableView.isHidden = !tableView.isHidden;
      counter = 0
    }
    counter+=1
  }

  @objc private func addButtonPressed() {
    let alertController = UIAlertController(title: "Create a new Channel", message: nil, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    alertController.addTextField { field in
      field.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
      field.enablesReturnKeyAutomatically = true
      field.autocapitalizationType = .words
      field.clearButtonMode = .whileEditing
      field.placeholder = "Channel name"
      field.returnKeyType = .done
      field.tintColor = .primary
    }

    let createAction = UIAlertAction(
      title: "Create",
      style: .default) { _ in
      self.createChannel()
    }
    createAction.isEnabled = false
    alertController.addAction(createAction)
    alertController.preferredAction = createAction

    present(alertController, animated: true) {
      alertController.textFields?.first?.becomeFirstResponder()
    }
    currentChannelAlertController = alertController
  }

  @objc private func textFieldDidChange(_ field: UITextField) {
    guard let alertController = currentChannelAlertController else {
      return
    }
    alertController.preferredAction?.isEnabled = field.hasText
  }

  // MARK: - Helpers
  private func createChannel() {
    guard
      let alertController = currentChannelAlertController,
      let channelName = alertController.textFields?.first?.text
    else {
      return
    }

    let channel = Channel(name: channelName)
    channelReference.addDocument(data: channel.representation) { error in
      if let error = error {
        print("Error saving channel: \(error.localizedDescription)")
      }
    }
  }

  private func addChannelToTable(_ channel: Channel) {
    if channels.contains(channel) {
      return
    }

    channels.append(channel)
    channels.sort()

    guard let index = channels.firstIndex(of: channel) else {
      return
    }
    DispatchQueue.main.async {
      // Update the UI on the main thread
      
    //  self.tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
      self.tableView.reloadData()
    }
  }

  private func updateChannelInTable(_ channel: Channel) {
    guard let index = channels.firstIndex(of: channel) else {
      return
    }

    channels[index] = channel
    tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  private func removeChannelFromTable(_ channel: Channel) {
    guard let index = channels.firstIndex(of: channel) else {
      return
    }

    channels.remove(at: index)
    tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }
  
  
  private func addLastSeenToTable(_ channel: LastOnline) {
//    if lastOnline.contains(channel) {
//      return
//    }
  
    
    lastOnline.removeAll { online in
      online.name == channel.name
    }
    
    
    lastOnline.append(channel)
    //self.lastOnline.sort(by: {$0.time > $1.time}) // this is it
    lastOnline =  lastOnline.sorted(by: { $0.time.compare($1.time) == .orderedDescending })
    lastOnline = lastOnline.sorted(by: {$0.time > $1.time})
    DispatchQueue.main.async {
      // Update the UI on the main thread
      self.tableView.reloadData()
    }
  //  tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  private func updateLastSeenInTable(_ channel: LastOnline) {
    guard let index = lastOnline.firstIndex(of: channel) else {
      return
    }

    lastOnline[index] = channel
    tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  private func removeLastSeenFromTable(_ channel: LastOnline) {
    guard let index = lastOnline.firstIndex(of: channel) else {
      return
    }

    lastOnline.remove(at: index)
    tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  private func handleDocumentChange(_ change: DocumentChange) {
    guard let channel = Channel(document: change.document) else {
      return
    }

    switch change.type {
    case .added:
      addChannelToTable(channel)
    case .modified:
      updateChannelInTable(channel)
    case .removed:
      removeChannelFromTable(channel)
    }
  }
  
  private func handleLastOnlineDocumentChange(_ change: DocumentChange) {
    guard let channel = LastOnline(document: change.document) else {
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
    
    DispatchQueue.main.async {
      // Update the UI on the main thread
      self.tableView.reloadData()
    }
  }
}

// MARK: - TableViewDelegate
extension ChannelsViewController {
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return showChannels ? channels.count : lastOnline.count
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 55
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: channelCellIdentifier, for: indexPath)
      cell.accessoryType = showChannels ? .disclosureIndicator : .none
    cell.textLabel?.text = showChannels ? channels[indexPath.row].name : "\(lastOnline[indexPath.row].name)"
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if(showChannels){
      let channel = channels[indexPath.row]
      AppController.shared.loadChat = true
      let viewController = ChatViewController(user: currentUser, channel: channel)
      navigationController?.pushViewController(viewController, animated: true)
    }
  }
}


extension Date {

    func toString(withFormat format: String = "dd MMM yyyy 'at' h:mm a") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = format
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
      dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let str = dateFormatter.string(from: self)
        return str
    }
}
