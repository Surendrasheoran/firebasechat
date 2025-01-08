import FirebaseFirestore

struct DeletedBy {
  let id: String?
  let name: String
  let time: String

  init(name: String, time: String) {
    id = nil
    self.name = name
    self.time = time
  }

  init?(document: QueryDocumentSnapshot) {
    let data = document.data()

    guard let name = data["name"] as? String else {
      return nil
    }
    
    guard let time = data["time"] as? String else {
      return nil
    }

    id = document.documentID
    self.name = name
    self.time = time
  }
}

// MARK: - DatabaseRepresentation
extension DeletedBy: DatabaseRepresentation {
  var representation: [String: Any] {
    var rep = ["name": name]

    if let id = id {
      rep["id"] = id
      rep["time"] = time
    }

    return rep
  }
}

// MARK: - Comparable
extension DeletedBy: Comparable {
  static func == (lhs: DeletedBy, rhs: DeletedBy) -> Bool {
    return lhs.id == rhs.id
  }

  static func < (lhs: DeletedBy, rhs: DeletedBy) -> Bool {
    return lhs.name < rhs.name
  }
}
