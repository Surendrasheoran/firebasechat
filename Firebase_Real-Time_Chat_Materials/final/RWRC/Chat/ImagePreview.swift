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

import Foundation
import UIKit
import FirebaseStorage
import SwiftUI

class ImagePreview: UIViewController, UICollectionViewDataSource {
  
  var heightImage: CGFloat = 0

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
   return AppDelegate.sharedImages.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let url = AppDelegate.sharedImages[indexPath.row] as String
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath as IndexPath)
    heightImage = heightImage * (CGFloat(indexPath.row))
    
    let imgView = UIImageView(frame: CGRect(x: 0, y: heightImage, width: self.view.frame.width, height: view.frame.height))
    imgView.image = UIImage(resource: .rwLogo)
    imgView.contentMode = .scaleAspectFit
    cell.addSubview(imgView)//Add image to our view
    downloadImage(imgView: imgView, url: url)
    return cell
  }
  
  
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = ""
//    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: #selector(clearData))
//
    
    let flowLayout = UICollectionViewFlowLayout();
    flowLayout.itemSize = CGSizeMake(view.frame.width, view.frame.height);
    let scrollView = UICollectionView(frame: self.view.frame, collectionViewLayout: flowLayout)
    scrollView.isScrollEnabled = true
    scrollView.dataSource = self
    scrollView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
    scrollView.minimumZoomScale = 1.0
    scrollView.maximumZoomScale = 10.0
    scrollView.isUserInteractionEnabled = true
  /* for url in AppDelegate.sharedImages {
      
      let imgView = UIImageView(frame: CGRect(x: 0, y: heightImage, width: view.frame.width, height: view.frame.height))
      imgView.image = UIImage(resource: .rwLogo)
      imgView.contentMode = .scaleAspectFit
      imgView.imgViewCorners()
      scrollView.addSubview(imgView)//Add image to our view
      downloadImage(imgView: imgView, url: url)
      heightImage += view.frame.height + 10
    }
    */
    scrollView.isScrollEnabled = true
    view.addSubview(scrollView)

    //Add image view properties like this(This is one of the way to add properties).
  }
  
  private func downloadImage(imgView: UIImageView, url: String) {

    if let cachedImage = AppDelegate.sharedImagesCache.object(forKey: url as NSString) {
      imgView.image = cachedImage
    }else
    {
      let ref = Storage.storage().reference(forURL: url)
      let megaByte = Int64(1 * 1024 * 1024)
      ref.getData(maxSize: megaByte) { data, _ in
        guard let imageData = data else {
          return
        }
        imgView.image = UIImage(data: imageData)
      }
    }
  }
}

extension UIImageView {
    //If you want only round corners
    func imgViewCorners() {
        layer.cornerRadius = 10
        layer.borderWidth = 1.0
        layer.masksToBounds = true
    }
}
