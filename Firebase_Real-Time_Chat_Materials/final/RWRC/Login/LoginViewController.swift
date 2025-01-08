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

final class LoginViewController: UIViewController {
  @IBOutlet private var actionButton: UIButton!
  @IBOutlet private var fieldBackingView: UIView!
  @IBOutlet private var emailBackingView: UIView!
  @IBOutlet private var passwordBackingView: UIView!
  @IBOutlet private var emailField: UITextField!
  @IBOutlet private var passwordField: UITextField!
  @IBOutlet private var bgView: UIImageView!
  @IBOutlet private var actionButtonBackingView: UIView!
  @IBOutlet private var bottomConstraint: NSLayoutConstraint!

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    fieldBackingView.smoothRoundCorners(to: 8)
    actionButtonBackingView.smoothRoundCorners(to: actionButtonBackingView.bounds.height / 2)

    emailField.tintColor = .primary
    emailField.addTarget(
      self,
      action: #selector(textFieldDidReturn),
      for: .primaryActionTriggered)
    
    passwordField.tintColor = .primary
    passwordField.addTarget(
      self,
      action: #selector(textFieldDidReturn),
      for: .primaryActionTriggered)

    registerForKeyboardNotifications()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    emailField.becomeFirstResponder()
    
//    emailBackingView.isHidden = true
//    passwordBackingView.isHidden = true
      actionButtonBackingView.isHidden = false
    
    let singleTap = UITapGestureRecognizer(target: self, action: #selector(self.signInDefault))
    singleTap.numberOfTapsRequired = 5;
//    singleTap.numberOfTouchesRequired = 1;
    fieldBackingView.addGestureRecognizer(singleTap)
    fieldBackingView.isUserInteractionEnabled = true
  }

  // MARK: - Actions
  @IBAction private func actionButtonPressed() {
    signIn()
  }

  @objc private func textFieldDidReturn() {
    signIn()
  }

  // MARK: - Helpers
  private func registerForKeyboardNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillShow(_:)),
      name: UIResponder.keyboardWillShowNotification,
      object: nil)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillHide(_:)),
      name: UIResponder.keyboardWillHideNotification,
      object: nil)
  }
  
  // default for demo
  @objc private func signInDefault()
  {
    Auth.auth().signIn(withEmail: "rest@testing.com", password: "123456")
    { (result, error) in
      print(error.debugDescription)
      print(result?.user.email)
      
      AppSettings.displayName = String(result?.user.email?.split(separator: "@").first ?? "rest")
    //  self.showMissingNameAlert()
    }
  }

  // default for rahul
  private func signIn() {
    emailField.resignFirstResponder()

    AppSettings.displayName = "rahul"
    
    Auth.auth().signIn(withEmail: emailField.text ?? "rahul@test.com", password: passwordField.text ?? "123456")
    { (result, error) in
      print(error.debugDescription)
      print(result?.user.email! as Any)
      AppSettings.displayName = String(result?.user.email?.split(separator: "@").first ?? "rahul")
    }
  }

  private func showMissingNameAlert() {
    let alertController = UIAlertController(
      title: "Display Name Required",
      message: "Please enter a display name.",
      preferredStyle: .alert)

    let action = UIAlertAction(
      title: "Okay",
      style: .default) { _ in
      self.emailField.becomeFirstResponder()
    }
    alertController.addAction(action)
    present(alertController, animated: true)
  }

  // MARK: - Notifications
  @objc private func keyboardWillShow(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let keyboardHeight = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height,
      let keyboardAnimationDuration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber),
      let keyboardAnimationCurve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)
    else {
      return
    }

    let options = UIView.AnimationOptions(rawValue: keyboardAnimationCurve.uintValue << 16)
    bottomConstraint.constant = keyboardHeight + 20

    UIView.animate(
      withDuration: keyboardAnimationDuration.doubleValue,
      delay: 0,
      options: options) {
      self.view.layoutIfNeeded()
    }
  }

  @objc private func keyboardWillHide(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let keyboardAnimationDuration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber),
      let keyboardAnimationCurve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)
    else {
      return
    }

    let options = UIView.AnimationOptions(rawValue: keyboardAnimationCurve.uintValue << 16)
    bottomConstraint.constant = 20

    UIView.animate(
      withDuration: keyboardAnimationDuration.doubleValue,
      delay: 0,
      options: options) {
      self.view.layoutIfNeeded()
    }
  }
}
