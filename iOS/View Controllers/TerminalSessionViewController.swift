//
//  TerminalSessionViewController.swift
//  NewTerm
//
//  Created by Adam Demasi on 10/1/18.
//  Copyright © 2018 HASHBANG Productions. All rights reserved.
//

import UIKit
import AudioToolbox

class TerminalSessionViewController: UIViewController {

	static let bellSoundID: SystemSoundID = {
		var soundID: SystemSoundID = 0
		if AudioServicesCreateSystemSoundID(Bundle.main.url(forResource: "bell", withExtension: "m4a")! as CFURL, &soundID) == kAudioServicesNoError {
			return soundID
		}
		fatalError("couldn’t initialise bell sound")
	}()

	var barInsets = UIEdgeInsets()

	private var terminalController = TerminalController()
	private var keyInput = TerminalKeyInput(frame: .zero)
	private var textView = TerminalTextView(frame: .zero, textContainer: nil)

	private lazy var bellHUDView: HUDView = {
		let image: UIImage
		if #available(iOS 13.0, *) {
			let configuration = UIImage.SymbolConfiguration(pointSize: 25, weight: .medium, scale: .large)
			image = UIImage(systemName: "bell", withConfiguration: configuration)!
		} else {
			image = #imageLiteral(resourceName: "bell").withRenderingMode(.alwaysTemplate)
		}
		let bellHUDView = HUDView(image: image)
		bellHUDView.translatesAutoresizingMaskIntoConstraints = false
		return bellHUDView
	}()

	private var hasAppeared = false
	private var hasStarted = false
	private var failureError: Error?

	private var keyboardHeight = CGFloat(0)
	private var lastAutomaticScrollOffset = CGPoint.zero
	private var invertScrollToTop = false

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		setUp()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setUp()
	}

	func setUp() {
		terminalController.delegate = self

		do {
			try terminalController.startSubProcess()
			hasStarted = true
		} catch {
			failureError = error
		}
	}

	override func loadView() {
		super.loadView()

		title = NSLocalizedString("TERMINAL", comment: "Generic title displayed before the terminal sets a proper title.")

		textView.showsVerticalScrollIndicator = false
		textView.delegate = self

		let gestureRecognizers = [
			UITapGestureRecognizer(target: self, action: #selector(self.handleTextViewTap(_:)))
		]

		for gestureRecognizer in gestureRecognizers {
			gestureRecognizer.delegate = self
			textView.addGestureRecognizer(gestureRecognizer)
		}

		keyInput.frame = view.bounds
		keyInput.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
		keyInput.textView = textView
		keyInput.terminalInputDelegate = terminalController
		view.addSubview(keyInput)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		addKeyCommand(UIKeyCommand(input: ",", modifierFlags: [ .command ], action: #selector(self.openSettings), discoverabilityTitle: NSLocalizedString("SETTINGS", comment: "Title of Settings page.")))

		addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(TerminalKeyInput.upKeyPressed)))
		addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(TerminalKeyInput.downKeyPressed)))
		addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(TerminalKeyInput.leftKeyPressed)))
		addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(TerminalKeyInput.rightKeyPressed)))
		addKeyCommand(UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(TerminalKeyInput.metaKeyPressed)))

		let letters = [
			"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r",
			"s", "t", "u", "v", "w", "x", "y", "z"
		]
		for key in letters {
			addKeyCommand(UIKeyCommand(input: key, modifierFlags: [ .control ], action: #selector(TerminalKeyInput.ctrlKeyCommandPressed(_:))))
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		registerForKeyboardNotifications()
		becomeFirstResponder()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		unregisterForKeyboardNotifications()
		resignFirstResponder()
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		updateScreenSize()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		if failureError != nil {
			let ok = NSLocalizedString("OK", tableName: "Localizable", bundle: Bundle(for: UIView.self), comment: "")
			let title = NSLocalizedString("TERMINAL_LAUNCH_FAILED", comment: "Alert title displayed when a terminal could not be launched.")

			let alertController = UIAlertController(title: title, message: failureError!.localizedDescription, preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: ok, style: .cancel, handler: nil))
			present(alertController, animated: true, completion: nil)
		}
	}

	override func removeFromParent() {
		if hasStarted {
			do {
				try terminalController.stopSubProcess()
			} catch {
				NSLog("failed to stop subprocess… %@", error as NSError)
			}
		}

		super.removeFromParent()
	}

	// MARK: - Screen

	func updateScreenSize() {
		// update the text view insets. if the keyboard height is non-zero, keyboard is visible and that’s
		// our bottom inset. else, it’s not and the bottom toolbar height is the bottom inset
		var newInsets = barInsets
		newInsets.bottom = keyboardHeight > 0 ? keyboardHeight : barInsets.bottom

		if #available(iOS 11.0, *) {
			newInsets.top -= view.safeAreaInsets.top
			newInsets.left = view.safeAreaInsets.left
			newInsets.right = view.safeAreaInsets.right
			textView.contentInset = newInsets

			var scrollInsets = newInsets
			scrollInsets.left = 0
			scrollInsets.right = 0
			textView.scrollIndicatorInsets = scrollInsets
		} else {
			textView.contentInset = newInsets
			textView.scrollIndicatorInsets = newInsets
		}

		let glyphSize = terminalController.fontMetrics.boundingBox

		// make sure the glyph size has been set
		if glyphSize.width == 0 || glyphSize.height == 0 {
			fatalError("failed to get the glyph size")
		}

		// Determine the screen size based on the font size
		let width = textView.frame.size.width
		let height = textView.frame.size.height - barInsets.top - newInsets.bottom

		let size = ScreenSize(width: UInt16(width / glyphSize.width), height: UInt16(height / glyphSize.height))

		// The font size should not be too small that it overflows the glyph buffers. It is not worth the
		// effort to fail gracefully (increasing the buffer size would be better).
		if size.width >= kMaxRowBufferSize {
			fatalError("screen size is too wide")
		}

		terminalController.screenSize = size
	}

	// MARK: - UIResponder

	@discardableResult override func becomeFirstResponder() -> Bool {
		return keyInput.becomeFirstResponder()
	}

	@discardableResult override func resignFirstResponder() -> Bool {
		return keyInput.resignFirstResponder()
	}

	override var isFirstResponder: Bool {
		return keyInput.isFirstResponder
	}

	// MARK: - Keyboard

	func scrollToBottom(animated: Bool = false) {
		// if the user has scrolled up far enough on their own, don’t rudely scroll them back to the
		// bottom. when they scroll back, the automatic scrolling will continue
		// TODO: buggy
		// if textView.contentOffset.y < lastAutomaticScrollOffset.y - 20 {
		// 	return
		// }

		// if there is no scrollback, use the top of the scroll view. if there is, calculate the bottom
		var insets: UIEdgeInsets
		if #available(iOS 13.0, *) {
			insets = textView.verticalScrollIndicatorInsets
		} else {
			insets = textView.scrollIndicatorInsets
		}
		var offset = textView.contentOffset
		let bottom = keyboardHeight > 0 ? keyboardHeight : insets.bottom

		if #available(iOS 11.0, *) {
			insets.top += view.safeAreaInsets.top
		}

		offset.y = terminalController.scrollbackLines() == 0 ? -insets.top : bottom + textView.contentSize.height - textView.frame.size.height

		// if the offset has changed, update it and our lastAutomaticScrollOffset
		if textView.contentOffset.y != offset.y {
			textView.setContentOffset(offset, animated: animated)
			lastAutomaticScrollOffset = offset
		}
	}

	func registerForKeyboardNotifications() {
		NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardVisibilityChanged(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardVisibilityChanged(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
	}

	func unregisterForKeyboardNotifications() {
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
	}

	@objc func keyboardVisibilityChanged(_ notification: Notification) {
		// we do this to avoid the scroll indicator from appearing as soon as the terminal appears.
		// we only want to see it after the keyboard has appeared
		if !hasAppeared {
			hasAppeared = false
			textView.showsVerticalScrollIndicator = true
		}

		// hide toolbar popups if visible
		keyInput.setMoreRowVisible(false, animated: true)

		// YES when showing, NO when hiding
		let direction = notification.name == UIResponder.keyboardWillShowNotification
		let animationDuration = notification.userInfo![UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval

		// determine the final keyboard height. we still get a height if hiding, so force it to 0 if this
		// isn’t a show notification
		let keyboardFrame = notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
		keyboardHeight = direction ? keyboardFrame.size.height : 0

		// we call updateScreenSize in an animation block to force it to be animated with the exact
		// parameters given to us in the notification
		UIView.animate(withDuration: animationDuration) {
			self.updateScreenSize()
		}
	}

	// MARK: - Gestures

	@objc func handleTextViewTap(_ gestureRecognizer: UITapGestureRecognizer) {
		if gestureRecognizer.state == .ended && !isFirstResponder {
			becomeFirstResponder()
		}
	}

}

extension TerminalSessionViewController: TerminalControllerDelegate {

	func refresh(attributedString: NSAttributedString, backgroundColor: UIColor) {
		textView.attributedText = attributedString

		if backgroundColor != textView.backgroundColor {
			textView.backgroundColor = backgroundColor
		}

		// TODO: not sure why this is needed all of a sudden? what did i break?
		DispatchQueue.main.async {
			self.scrollToBottom()
		}
	}

	func activateBell() {
		let preferences = Preferences.shared

		if preferences.bellHUD {
			// display the bell HUD, lazily initialising it if it hasn’t been yet
			if bellHUDView.superview == nil {
				view.addSubview(bellHUDView)
				view.addCompactConstraints([
					"hudView.centerX = self.centerX",
					"hudView.centerY = self.centerY / 3"
				], metrics: nil, views: [
					"self": view!,
					"hudView": bellHUDView
				])
			}

			bellHUDView.animate()
		}

		if preferences.bellVibrate {
			// According to the docs, we should let the feedback generator get deallocated so the
			// Taptic Engine goes back to sleep afterwards.
			// Also according to the docs, we should use the most semantic impact generator, which would
			// be UINotificationFeedbackGenerator, but I think a single tap feels better than two or three
			let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
			feedbackGenerator.impactOccurred()
		}

		if preferences.bellSound {
			AudioServicesPlaySystemSound(TerminalSessionViewController.bellSoundID)
		}
	}

	@objc func close() {
		// TODO: i guess this is kind of the wrong spot
		if let rootViewController = parent as? RootViewController {
			rootViewController.removeTerminal(terminal: self)
		}
	}

	func didReceiveError(error: Error) {
		if !hasAppeared {
			failureError = error
			return
		}

		let ok = NSLocalizedString("OK", tableName: "Localizable", bundle: Bundle(for: UIView.self), comment: "")
		// TODO: this string is wrong!
		let title = NSLocalizedString("TERMINAL_LAUNCH_FAILED", comment: "Alert title displayed when a terminal could not be launched.")

		let nsError = error as NSError
		let alertController = UIAlertController(title: title, message: nsError.localizedDescription, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: ok, style: .cancel, handler: nil))
		present(alertController, animated: true, completion: nil)
	}

	@objc func openSettings() {
		if presentedViewController == nil {
			let rootController = PreferencesRootController()
			rootController.modalPresentationStyle = .formSheet
			navigationController!.present(rootController, animated: true, completion: nil)
		}
	}

}

extension TerminalSessionViewController: UITextViewDelegate {

	func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		// hide toolbar popups if visible
		keyInput.setMoreRowVisible(false, animated: true)
	}

	func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
		let insets: UIEdgeInsets
		if #available(iOS 13.0, *) {
			insets = scrollView.verticalScrollIndicatorInsets
		} else {
			insets = scrollView.scrollIndicatorInsets
		}

		// if we’re at the top of the scroll view, guess that the user wants to go back to the bottom
		if scrollView.contentOffset.y <= (scrollView.frame.size.height - insets.top - insets.bottom) / 2 {
			// wrapping in an animate block as a hack to avoid strange content inset issues, unfortunately
			UIView.animate(withDuration: 0.5) {
				self.scrollToBottom(animated: true)
			}

			return false
		}

		return true
	}

	func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
		// since the scroll view is at {0, 0}, it won’t respond to scroll to top events till the next
		// scroll. trick it by scrolling 1 physical pixel up
		scrollView.contentOffset.y -= CGFloat(1) / UIScreen.main.scale
	}

}

// yes another delegate extension, sorry
extension TerminalSessionViewController: UIGestureRecognizerDelegate {

	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}

}
