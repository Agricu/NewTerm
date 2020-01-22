//
//  RootViewController.swift
//  NewTerm
//
//  Created by Adam Demasi on 10/1/18.
//  Copyright © 2018 HASHBANG Productions. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {

	var terminals: [TerminalSessionViewController] = []
	var selectedTabIndex = Int(0)

	var tabToolbar = TabToolbar()

	var tabsCollectionView: UICollectionView {
		return tabToolbar.tabsCollectionView
	}

	override func loadView() {
		super.loadView()

		navigationController!.isNavigationBarHidden = true

		tabToolbar.autoresizingMask = [ .flexibleWidth ]
		tabToolbar.addButton.addTarget(self, action: #selector(self.addTerminal), for: .touchUpInside)

		tabsCollectionView.dataSource = self
		tabsCollectionView.delegate = self

		view.addSubview(tabToolbar)

		addTerminal()

		addKeyCommand(UIKeyCommand(input: "t", modifierFlags: [ .command ], action: #selector(self.addTerminal), discoverabilityTitle: NSLocalizedString("NEW_TAB", comment: "VoiceOver label for the new tab button.")))
		addKeyCommand(UIKeyCommand(input: "w", modifierFlags: [ .command ], action: #selector(self.removeCurrentTerminal), discoverabilityTitle: NSLocalizedString("CLOSE_TAB", comment: "VoiceOver label for the close tab button.")))

		if #available(iOS 13.0, *), UIApplication.shared.supportsMultipleScenes {
			addKeyCommand(UIKeyCommand(input: "n", modifierFlags: [ .command ], action: #selector(self.addWindow), discoverabilityTitle: NSLocalizedString("NEW_WINDOW", comment: "VoiceOver label for the new window button.")))
			addKeyCommand(UIKeyCommand(input: "w", modifierFlags: [ .command, .shift ], action: #selector(self.closeCurrentWindow), discoverabilityTitle: NSLocalizedString("CLOSE_WINDOW", comment: "VoiceOver label for the close window button.")))

			tabToolbar.addButton.addInteraction(UIContextMenuInteraction(delegate: self))
		}
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()

		let barHeight = CGFloat(isSmallDevice ? 32 : 40)

		let topMargin: CGFloat

		if #available(iOS 11.0, *) {
			topMargin = view.safeAreaInsets.top
		} else {
			topMargin = UIApplication.shared.statusBarFrame.size.height
		}

		tabToolbar.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: topMargin + barHeight)
		tabToolbar.topMargin = topMargin

		let barInsets = UIEdgeInsets(top: tabToolbar.frame.size.height, left: 0, bottom: 0, right: 0)

		for viewController in terminals {
			viewController.barInsets = barInsets
		}
	}

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}

	// MARK: - Tab management

	@IBAction func addTerminal() {
		let terminalViewController = TerminalSessionViewController()

		addChild(terminalViewController)
		terminalViewController.willMove(toParent: self)
		view.insertSubview(terminalViewController.view, belowSubview: tabToolbar)
		terminalViewController.didMove(toParent: self)

		terminals.append(terminalViewController)

		tabsCollectionView.reloadData()
		tabsCollectionView.layoutIfNeeded()
		switchToTab(index: terminals.count - 1)
		tabsCollectionView.reloadData()
	}

	func removeTerminal(terminal terminalViewController: TerminalSessionViewController) {
		guard let index = terminals.firstIndex(of: terminalViewController) else {
			NSLog("asked to remove terminal that doesn’t exist? %@", terminalViewController)
			return
		}

		terminalViewController.removeFromParent()
		terminalViewController.view.removeFromSuperview()

		terminals.remove(at: index)

		// If this was the last tab, close the window (or make a new tab if not supported). Otherwise
		// select the closest tab we have available
		if terminals.count == 0 {
			if #available(iOS 13.0, *), UIApplication.shared.supportsMultipleScenes {
				closeCurrentWindow()
			} else {
				addTerminal()
			}
		} else {
			tabsCollectionView.reloadData()
			tabsCollectionView.layoutIfNeeded()
			switchToTab(index: index >= terminals.count ? index - 1 : index)
		}
	}

	func removeTerminal(index: Int) {
		removeTerminal(terminal: terminals[index])
	}

	@objc func removeTerminalButtonTapped(_ button: UIButton) {
		removeTerminal(index: button.tag)
	}

	@IBAction func removeCurrentTerminal() {
		removeTerminal(index: selectedTabIndex)
	}

	@IBAction func removeAllTerminals() {
		for terminalViewController in terminals {
			terminalViewController.removeFromParent()
			terminalViewController.view.removeFromSuperview()
		}

		terminals.removeAll()
		addTerminal()
	}

	func switchToTab(index: Int) {
		// if this is what’s already selected, just select it again and return
		if index == selectedTabIndex {
			tabsCollectionView.selectItem(at: IndexPath(item: selectedTabIndex, section: 0), animated: true, scrollPosition: .centeredHorizontally)
		}

		let oldSelectedTabIndex = selectedTabIndex < terminals.count ? selectedTabIndex : nil

		// if the previous index is now out of bounds, just use nil as our previous. the tab and view
		// controller were removed so we don’t need to do anything
		let previousViewController = oldSelectedTabIndex == nil ? nil : terminals[oldSelectedTabIndex!]
		let newViewController = terminals[index]

		selectedTabIndex = index

		// call the appropriate view controller lifecycle methods on the previous and new view controllers
		previousViewController?.viewWillDisappear(false)
		previousViewController?.view.isHidden = true
		previousViewController?.viewDidDisappear(false)

		newViewController.viewWillAppear(false)
		newViewController.view.isHidden = false
		newViewController.viewDidAppear(false)

		tabsCollectionView.performBatchUpdates({
			if oldSelectedTabIndex != nil {
				self.tabsCollectionView.deselectItem(at: IndexPath(item: oldSelectedTabIndex!, section: 0), animated: false)
			}

			self.tabsCollectionView.selectItem(at: IndexPath(item: selectedTabIndex, section: 0), animated: true, scrollPosition: .centeredHorizontally)
		}, completion: { _ in
			// TODO: hack because the previous tab doesn’t deselect for some reason and ugh i hate this
			self.tabsCollectionView.reloadData()
		})
	}

	// MARK: - Window management

	@available(iOS 13.0, *)
	@IBAction func addWindow() {
		let options = UIWindowScene.ActivationRequestOptions()
		options.requestingScene = view.window!.windowScene
		UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: options, errorHandler: nil)
	}

	@available(iOS 13.0, *)
	@IBAction func closeCurrentWindow() {
		UIApplication.shared.requestSceneSessionDestruction(view.window!.windowScene!.session, options: nil, errorHandler: nil)
	}

}

extension RootViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return terminals.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let terminalViewController = terminals[indexPath.row]

		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabCollectionViewCell.reuseIdentifier, for: indexPath) as! TabCollectionViewCell
		cell.textLabel.text = terminalViewController.title
		cell.isSelected = selectedTabIndex == indexPath.row
		cell.closeButton.tag = indexPath.row
		cell.closeButton.addTarget(self, action: #selector(self.removeTerminalButtonTapped(_:)), for: .touchUpInside)
		cell.isLastItem = indexPath.row == terminals.count - 1
		return cell
	}

	func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		return CGSize(width: 100, height: tabsCollectionView.frame.size.height)
	}

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		switchToTab(index: indexPath.row)
	}

}

@available(iOS 13.0, *)
extension RootViewController: UIContextMenuInteractionDelegate {

	func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
		if !UIApplication.shared.supportsMultipleScenes {
			return nil
		}
		return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ -> UIMenu? in
			return UIMenu(title: "", children: [
				UICommand(title: NSLocalizedString("NEW_WINDOW", comment: "VoiceOver label for the new window button."), image: UIImage(systemName: "plus.rectangle.on.rectangle"), action: #selector(self.addWindow)),
				UICommand(title: NSLocalizedString("CLOSE_WINDOW", comment: "VoiceOver label for the close window button."), image: UIImage(systemName: "xmark.rectangle"), action: #selector(self.closeCurrentWindow))
			])
		})
	}

}
