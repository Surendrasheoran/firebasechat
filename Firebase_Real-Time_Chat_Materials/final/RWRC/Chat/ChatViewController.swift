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
import Photos
import Firebase
import MessageKit
import InputBarAccessoryView
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

final class ChatViewController: MessagesViewController, UITextViewDelegate {
  private var isSendingPhoto = false {
    didSet {
      messageInputBar.leftStackViewItems.forEach { item in
        guard let item = item as? InputBarButtonItem else {
          return
        }
        item.isEnabled = !self.isSendingPhoto
      }
    }
  }
  
  private let database = Firestore.firestore()
  private var reference: CollectionReference?
  private let storage = Storage.storage().reference()
  
  var backgroundTaskID: UIBackgroundTaskIdentifier!

  
  private var deletedByReference: CollectionReference {
    return database.collection("deletedBy")
  }
  
  private var lastreadByReference: CollectionReference {
    return database.collection("lastread")
  }
  
  
  private var messages: [Message] = []
  private var messageListener: ListenerRegistration?
  
  private let user: User
  private let channel: Channel
  let imageCache = NSCache<NSString, NSData>()

  deinit {
    messageListener?.remove()
  }
  
  init(user: User, channel: Channel) {
    self.user = user
    self.channel = channel
    super.init(nibName: nil, bundle: nil)
    
    title = "Page 2"
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  
  private func deletedByEntry() {
    database.collection("deletedBy").getDocuments { (querySnapshot, error) in
      if error != nil {
        print(error)
      } else {
        for document in querySnapshot!.documents {
          Task{
            try await self.database.collection("deletedBy").document(document.documentID).delete()
            print("Document successfully removed! \(document.documentID)")
          }
        }
        
          Task{
            try await Task.sleep(nanoseconds: 1000)
            let lastOnline = DeletedBy(name: "Deleted By \(AppSettings.displayName) at \(Date.now.toString())", time: Date.now.description)
            self.deletedByReference.addDocument(data: lastOnline.representation) { error in
              if let error = error {
                print("Error saving DeletedBy: \(error.localizedDescription)")
              }
              else
              {
                print("Document successfully added! ")
              }
            }
        }
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    listenToMessages()
    navigationItem.largeTitleDisplayMode = .never
    //    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: #selector(clearData))
    //
    toolbarItems = [
      UIBarButtonItem(title: "--", style: .plain, target: self, action: #selector(clearData)),
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(title: ".", style: .plain, target: self, action: #selector(showList)),
    ]
    
    navigationItem.rightBarButtonItems = toolbarItems
    
    let notificationCenter = NotificationCenter.default
       notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    
    setUpMessageView()
    removeMessageAvatars()
    addCameraBarButton()
    
    
    let title = getNotificationTitle();
    let subTitle = getNotificationSubTitle();
    let msg = getNotificationMsg();

    
    AppDelegate.sendNotificationToAll(title: title, subTitle: subTitle, message: msg)
  }
  
  @objc func appMovedToBackground() {
      // do whatever event you want
    AppController.shared.show(in: AppController.shared.window)
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

//    AppController.shared.window.willRemoveSubview(self.messagesCollectionView)
//    AppController.shared.window.isHidden = true
  
    messagesCollectionView.isHidden = true
  //  exit(0)
  }
  
  func getNotificationTitle() -> String {
    
    
    return "Vehicle status update"
  }
  
  func getNotificationSubTitle() -> String {
    return "Parts available for repair"
  }
  
  func getNotificationMsg() -> String {
    return "For more details please click "
  }
  
  override func viewWillAppear(_ animated: Bool) {
    messagesCollectionView.isHidden = true
    self.messagesCollectionView.scrollToLastItem()
    
    backgroundTaskID = UIApplication.shared.beginBackgroundTask()
           DispatchQueue.global().asyncAfter(deadline: .now() + 15) {[weak self] in
               Utility.checkDeviceLockState() {
                   lockState in
                   if let self = self {
                     if lockState == DeviceLockState.locked{
                       self.appMovedToBackground()
                       UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                     }
                   }
               }
           }
  }
  
  
  private func listenToMessages() {
    guard let id = channel.id else {
      navigationController?.popViewController(animated: true)
      return
    }
    
    reference = database.collection("channels/\(id)/thread")
    
    messageListener = reference?.addSnapshotListener { [weak self] querySnapshot, error in
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
  
  private func setUpMessageView() {
    maintainPositionOnKeyboardFrameChanged = true
    messageInputBar.inputTextView.tintColor = .primary
    messageInputBar.sendButton.setTitleColor(.primary, for: .normal)

    messageInputBar.delegate = self
    messagesCollectionView.messagesDataSource = self
    messagesCollectionView.messagesLayoutDelegate = self
    messagesCollectionView.messagesDisplayDelegate = self
    messagesCollectionView.messageCellDelegate = self;
    
    Task{
      if(AppSettings.displayName.contains("rahul")){
        try await Task.sleep(nanoseconds: 1000)
        let lastOnline = DeletedBy(name: "\(self.channel.name) --- By --- \(AppSettings.displayName) at \(Date.now.toString())", time: Date.now.description)
        self.lastreadByReference.addDocument(data: lastOnline.representation) { error in
          if let error = error {
            print("Error saving DeletedBy: \(error.localizedDescription)")
          }
          else
          {
            print("Document successfully added! ")
          }
        }
      }
    }
  }
  
  private func removeMessageAvatars() {
    guard let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout else {
      return
    }
    layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
    layout.textMessageSizeCalculator.incomingAvatarSize = .zero
    layout.setMessageIncomingAvatarSize(.zero)
    layout.setMessageOutgoingAvatarSize(.zero)
    let incomingLabelAlignment = LabelAlignment(
      textAlignment: .left,
      textInsets: UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0))
    layout.setMessageIncomingMessageTopLabelAlignment(incomingLabelAlignment)
    let outgoingLabelAlignment = LabelAlignment(
      textAlignment: .right,
      textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 15))
    layout.setMessageOutgoingMessageTopLabelAlignment(outgoingLabelAlignment)
  }
  
  private func addCameraBarButton() {
    let cameraItem = InputBarButtonItem(type: .system)
    cameraItem.tintColor = .primary
    cameraItem.image = UIImage(named: "camera")
    cameraItem.addTarget(
      self,
      action: #selector(cameraButtonPressed),
      for: .primaryActionTriggered)
    cameraItem.setSize(CGSize(width: 60, height: 30), animated: false)
    
    messageInputBar.leftStackView.alignment = .center
    messageInputBar.setLeftStackViewWidthConstant(to: 50, animated: false)
    messageInputBar.setStackViewItems([cameraItem], forStack: .left, animated: false)
  }
  
  @objc private func showList()
  {
    messagesCollectionView.isHidden = !messagesCollectionView.isHidden
  }
  
  private var channelReference: CollectionReference {
    return database.collection("channels")
  }
  
  @objc private func clearData()
  {
    print("Document successfully removed! \(channelReference.debugDescription)")

    channelReference.addSnapshotListener { [weak self] querySnapshot, error in
      guard let self = self else { return }
      guard let snapshot = querySnapshot else {
        print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
        return
      }
      
      for document in snapshot.documents {
        Task{
          if(document.documentID == self.channel.id){
            try await self.database.collection("channels").document(document.documentID).delete()
            print("Document successfully removed! \(document.documentID)")
            self.deletedByEntry()
          }
        }
      }
      
      self.navigationController?.popViewController(animated: false);

    }
  }
  
  private func deleteImages() async
  {
    do {
      let imageCollection = try await storage.listAll()
      for image in imageCollection.prefixes {
        
        let imagelist = try await storage.child(image.name).listAll()
        for image in imagelist.items {
          let desertRef = storage.child(image.name)
          desertRef.delete { error in
            print("Error deleting image: \(error?.localizedDescription)")
          }
        }
      }
      
    } catch {
      print("Error deleting image: \(error.localizedDescription)")
    }
  }
  // MARK: - Actions
  @objc private func cameraButtonPressed() {
    
    
    let myActionSheet =  UIAlertController(title: "Images from:", message: "", preferredStyle: UIAlertController.Style.actionSheet)
    myActionSheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
    myActionSheet.addAction(UIAlertAction(title: "Camera", style: UIAlertAction.Style.default, handler: { (ACTION :UIAlertAction!)in
       
         self.selectPick(sourceType: UIImagePickerController.SourceType.camera)
         
       }))
    myActionSheet.addAction(UIAlertAction(title: "Gallery", style: UIAlertAction.Style.destructive, handler: { (ACTION :UIAlertAction!)in
      self.selectPick(sourceType: UIImagePickerController.SourceType.photoLibrary)

      }))
    self.present(myActionSheet, animated: true, completion: nil)
    
  }
  
  func selectPick(sourceType: UIImagePickerController.SourceType)  {
    let picker = UIImagePickerController()
    picker.delegate = self
    
    picker.sourceType = sourceType
    self.present(picker, animated: true)
  }
  
  // MARK: - Helpers
  private func save(_ message: Message) {
    reference?.addDocument(data: message.representation) { [weak self] error in
      guard let self = self else { return }
      if let error = error {
        print("Error sending message: \(error.localizedDescription)")
        return
      }
      self.messagesCollectionView.scrollToLastItem()
    }
  }
  
  private func insertNewMessage(_ message: Message) {
    if messages.contains(message) {
      return
    }
    
    messages.append(message)
    messages.sort()
    
    let isLatestMessage = messages.firstIndex(of: message) == (messages.count - 1)
    let shouldScrollToBottom = messagesCollectionView.isAtBottom && isLatestMessage
    
    messagesCollectionView.reloadData()
    
    if shouldScrollToBottom {
      messagesCollectionView.scrollToLastItem(animated: true)
    }
  }
  
  private func handleDocumentChange(_ change: DocumentChange) {
    guard var message = Message(document: change.document) else {
      return
    }
    
    switch change.type {
    case .added:
      if let url = message.downloadURL {
        downloadImage(at: url) { [weak self] image in
          guard
            let self = self,
            let image = image
          else {
            return
          }
          message.image = image
          self.insertNewMessage(message)
        }
      } else {
        insertNewMessage(message)
      }
    default:
      break
    }
    
    self.messagesCollectionView.scrollToLastItem()
    
  }
  
  private func uploadImage(
    _ image: UIImage,
    to channel: Channel,
    completion: @escaping (URL?) -> Void
  ) {
    guard
      let channelId = channel.id,
      let scaledImage = image.scaledToSafeUploadSize,
      let data = scaledImage.jpegData(compressionQuality: 0.4)
    else {
      return completion(nil)
    }
    
    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"
    
    let imageName = [UUID().uuidString, String(Date().timeIntervalSince1970)].joined()
    let imageReference = storage.child("\(channelId)/\(imageName)")
    imageReference.putData(data, metadata: metadata) { _, _ in
      imageReference.downloadURL { url, _ in
        completion(url)
      }
    }
  }
  
  private func sendPhoto(_ image: UIImage) {
    isSendingPhoto = true
    
    uploadImage(image, to: channel) { [weak self] url in
      guard let self = self else { return }
      self.isSendingPhoto = false
      
      guard let url = url else {
        return
      }
      
      var message = Message(user: self.user, image: image)
      message.downloadURL = url
      
      self.save(message)
      self.messagesCollectionView.scrollToLastItem()
    }
  }
  
  private func downloadImage(at url: URL, completion: @escaping (UIImage?) -> Void) {
    
    if let cachedImage = AppDelegate.sharedImagesCache.object(forKey: url.absoluteString as NSString) {
      completion(cachedImage)
    } else {
      let ref = Storage.storage().reference(forURL: url.absoluteString)
      let megaByte = Int64(1 * 1024 * 1024)
      AppDelegate.sharedImages.append(url.absoluteString)
      ref.getData(maxSize: megaByte) { data, _ in
        guard let imageData = data else {
          completion(nil)
          return
        }
        AppDelegate.sharedImagesCache.setObject(UIImage(data: imageData) ?? UIImage(resource: .rwLogo), forKey: url.absoluteString as NSString)
        completion(UIImage(data: imageData))
      }
      self.messagesCollectionView.scrollToLastItem()
    }
  }
}
// MARK: - MessagesDisplayDelegate
extension ChatViewController: MessagesDisplayDelegate {
  func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
    return isFromCurrentSender(message: message) ? .purple : .incomingMessage1
  }

  func shouldDisplayHeader(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> Bool {
    return false
  }

  func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
    avatarView.isHidden = false
  }

  func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
    let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
    return .bubbleTail(corner, .pointedEdge)
  }
}

// MARK: - MessagesLayoutDelegate
extension ChatViewController: MessagesLayoutDelegate {
  func footerViewSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
    return CGSize(width: 0, height: 8)
  }

  func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    return 20
  }
}

// MARK: - MessagesDataSource
extension ChatViewController: MessagesDataSource {
  func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
    return messages.count
  }

  func currentSender() -> SenderType {
    return Sender(senderId: user.uid, displayName: AppSettings.displayName)
  }

  func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
    return messages[indexPath.section]
  }

  func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
    let name = "\(message.sender.displayName)  \(message.sentDate.formatted(date: .abbreviated, time: .shortened))"
    return NSAttributedString(
      string: name,
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .caption1),
        .foregroundColor: UIColor(white: 0.3, alpha: 1)
      ])
  }
}

// MARK: - InputBarAccessoryViewDelegate
extension ChatViewController: InputBarAccessoryViewDelegate {
  func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
    let message = Message(user: user, content: text)
    save(message)
    inputBar.inputTextView.text = ""
  }
}

// MARK: - UIImagePickerControllerDelegate
extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true)

    if let asset = info[.phAsset] as? PHAsset {
      let size = CGSize(width: 500, height: 500)
      PHImageManager.default().requestImage(
        for: asset,
        targetSize: size,
        contentMode: .aspectFit,
        options: nil
      ) { result, _ in
        guard let image = result else {
          return
        }
        self.sendPhoto(image)
      }
    } else if let image = info[.originalImage] as? UIImage {
      sendPhoto(image)
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
  }
}

extension ChatViewController: MessageCellDelegate{
  func didTapImage(in cell: MessageCollectionViewCell) {
    print("cell click")
    let viewController = ImagePreview()
    navigationController?.pushViewController(viewController, animated: true)
  }
  
  func didTapMessage(in cell: MessageCollectionViewCell) {
    print("cell click \(cell)")
    //let viewController = ImagePreview()
  //  navigationController?.pushViewController(viewController, animated: true)
  }
}
