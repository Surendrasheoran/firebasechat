import FirebaseFirestore

struct fcmToken {
  let id: String?
  let email: String
  let fcmToken: String

  init(email: String, token: String) {
    id = nil
    self.email = email
    self.fcmToken = token
  }

  init?(document: QueryDocumentSnapshot) {
    let data = document.data()

    guard let name = data["email"] as? String else {
      return nil
    }
    
    guard let time = data["fcmToken"] as? String else {
      return nil
    }

    id = document.documentID
    self.email = name
    self.fcmToken = time
  }
}

// MARK: - DatabaseRepresentation
extension fcmToken: DatabaseRepresentation {
  var representation: [String: Any] {
    var rep = ["email": email]

      rep["id"] = fcmToken
      rep["email"] = email
      rep["fcmToken"] = fcmToken

    return rep
  }
}

// MARK: - Comparable
extension fcmToken: Comparable {
  static func == (lhs: fcmToken, rhs: fcmToken) -> Bool {
    return lhs.fcmToken == rhs.fcmToken
  }

  static func < (lhs: fcmToken, rhs: fcmToken) -> Bool {
    return lhs.fcmToken < rhs.fcmToken
  }
  
}
