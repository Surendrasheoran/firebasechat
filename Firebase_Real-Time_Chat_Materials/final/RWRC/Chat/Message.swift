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
import Firebase
import MessageKit
import FirebaseFirestore
import FirebaseAuth

struct Message: MessageType {
  let id: String?
  var messageId: String {
    return id ?? UUID().uuidString
  }
  let content: String
  let sentDate: Date
  let sender: SenderType
  var kind: MessageKind {
    if let image = image {
      let mediaItem = ImageMediaItem(image: image)
      return .photo(mediaItem)
    } else {
      return .text(content)
    }
  }

  var image: UIImage?
  var downloadURL: URL?

  init(user: User, content: String) {
    sender = Sender(senderId: user.uid, displayName: AppSettings.displayName)
    self.content = content
    sentDate = Date()
    id = nil
  }

  init(user: User, image: UIImage) {
    sender = Sender(senderId: user.uid, displayName: AppSettings.displayName)
    self.image = image
    content = ""
    sentDate = Date()
    id = nil
  }

  init?(document: QueryDocumentSnapshot) {
    let data = document.data()
    guard
      let sentDate = data["created"] as? Timestamp,
      let senderId = data["senderId"] as? String,
      let senderName = data["senderName"] as? String
    else {
      return nil
    }

    id = document.documentID

    self.sentDate = sentDate.dateValue()
    sender = Sender(senderId: senderId, displayName: senderName)

    if let content = data["content"] as? String {
      self.content = content
      downloadURL = nil
    } else if let urlString = data["url"] as? String, let url = URL(string: urlString) {
      downloadURL = url
      content = ""
    } else {
      return nil
    }
  }
}

// MARK: - DatabaseRepresentation
extension Message: DatabaseRepresentation {
  var representation: [String: Any] {
    var rep: [String: Any] = [
      "created": sentDate,
      "senderId": sender.senderId,
      "senderName": sender.displayName
    ]

    if let url = downloadURL {
      rep["url"] = url.absoluteString
    } else {
      rep["content"] = content
    }

    return rep
  }
}

// MARK: - Comparable
extension Message: Comparable {
  static func == (lhs: Message, rhs: Message) -> Bool {
    return lhs.id == rhs.id
  }

  static func < (lhs: Message, rhs: Message) -> Bool {
    return lhs.sentDate < rhs.sentDate
  }
}
