import FirebaseFirestore

struct LastOnline {
  let id: String?
  let name: String
  let timeString: String
  let time: Date

  init(name: String, time: Date) {
    id = "\(AppSettings.displayName) \(Date.now.toStringUserFriendlyOnlyTime())"
    self.name = name
    self.time = time
    self.timeString = ""
  }

  init?(document: QueryDocumentSnapshot) {
    let data = document.data()

    guard let name = data["name"] as? String else {
      return nil
    }
    
    guard let timeS = data["time"] as? String else {
      return nil
    }

    id = document.documentID
    self.name = name
    self.time = timeS.toStringUserFriendly()
    self.timeString = timeS
  }
}

// MARK: - DatabaseRepresentation
extension LastOnline: DatabaseRepresentation {
  var representation: [String: Any] {
    var rep = ["name": name]

    if let id = id {
      rep["id"] = id
      rep["time"] = time.toString()  //Date.now.toStringUserFriendlyOnlyDate()
    }

    return rep
  }
}

// MARK: - Comparable
extension LastOnline: Comparable {
  static func == (lhs: LastOnline, rhs: LastOnline) -> Bool {
    return lhs.time == rhs.time
  }

  static func < (lhs: LastOnline, rhs: LastOnline) -> Bool {
    return lhs.time < rhs.time
  }
  
}

extension Array {
    func unique<T:Hashable>(map: ((Element) -> (T)))  -> [Element] {
        var set = Set<T>() //the unique list kept in a Set for fast retrieval
        var arrayOrdered = [Element]() //keeping the unique list of elements but ordered
        for value in self {
            if !set.contains(map(value)) {
                set.insert(map(value))
                arrayOrdered.append(value)
            }
        }

        return arrayOrdered
    }
}


extension String{
  
  func toStringUserFriendly(withFormat format: String = "dd MMM yyyy 'at' h:mm a") -> Date {
      let dateFormatter = DateFormatter()
      dateFormatter.calendar = Calendar(identifier: .gregorian)
      dateFormatter.dateFormat = format
      dateFormatter.amSymbol = "AM"
      dateFormatter.pmSymbol = "PM"
    dateFormatter.locale = Locale.current
    dateFormatter.timeZone = TimeZone.current
      let str = dateFormatter.date(from: self)
  //  print("\(str!) ==== \(self)")
      return str ?? Date.now
  }
  
}


extension Date {

    func toStringUserFriendly(withFormat format: String = "dd MMM yyyy 'at' h:mm a") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = format
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        let str = dateFormatter.string(from: self)
        return str
    }
  
  func toStringUserFriendlyOnlyTime(withFormat format: String = "h:mm:ss a") -> String {
      let dateFormatter = DateFormatter()
      dateFormatter.calendar = Calendar(identifier: .gregorian)
      dateFormatter.dateFormat = format
      dateFormatter.amSymbol = "AM"
      dateFormatter.pmSymbol = "PM"
      let str = dateFormatter.string(from: self)
      return str
  }
  
  func toStringUserFriendlyOnlyDate(withFormat format: String = "dd MMM yyyy") -> String {
      let dateFormatter = DateFormatter()
      dateFormatter.calendar = Calendar(identifier: .gregorian)
      dateFormatter.dateFormat = format
      dateFormatter.amSymbol = "AM"
      dateFormatter.pmSymbol = "PM"
      let str = dateFormatter.string(from: self)
      return str
  }
    
    func toReadableString(withFormat format: String = "EEEE") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = format
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        let str = dateFormatter.string(from: self)
        return str
    }
    
    func toDefaultString(withFormat format: String = "yyyy-MM-dd") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = format
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        let str = dateFormatter.string(from: self)
        return str
    }
    
    func adding(day: Int) -> Date {
           return Calendar.current.date(byAdding: .day, value: day, to: self)!
       }
}

