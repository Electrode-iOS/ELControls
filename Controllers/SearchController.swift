//
//  SearchController.swift
//
//  Created by Sam Grover on 7/2/15.
//  Copyright (c) 2015 WalmartLabs. All rights reserved.
//

import UIKit

/**
This class provides a view controller for a search interface that has two states, Empty (when the search bar has no text), and Typeahead (when there's text in the search bar).
There's a plain table view for each state. The init takes separate tableview data sources and deleagtes for each state.
All views are managed programatically via this class. The search bar is accessible for customization.
In order to set up a delegate for the search bar, please only do so via the searchBarDelegate property on this class.
*/
@objc(THGSearchController)
class SearchController: UIViewController, UISearchBarDelegate {
    
    private enum SearchControllerState { case Empty, Typeahead }
    
    private let emptyResultsTableView: UITableView
    private let emptyResultsDataSource: UITableViewDataSource
    private let emptyResultsDelegate: UITableViewDelegate
    
    private let typeaheadResultsTableView: UITableView
    private let typeaheadResultsDataSource: UITableViewDataSource
    private let typeaheadResultsDelegate: UITableViewDelegate
    
    private let searchBarHeight: CGFloat = 44.0
    private var state: SearchControllerState
    
    /**
    The search bar displayed at the top of the search controller. It can be customized  after init.
    */
    let searchBar: UISearchBar
    
    /**
    The proxy for the searchBar's delegate. All the UISearchBarDelegate protocol methods will be forwarded.
    If this is left nil, this view controller will dismiss itself when the cancel button is tapped.
    Otherwise dismissing this view controller is the responsibility of the creating object.
    */
    weak var searchBarDelegate: UISearchBarDelegate?
    
    init(emptyResultsDataSource: UITableViewDataSource, emptyResultsDelegate: UITableViewDelegate, typeaheadResultsDataSource: UITableViewDataSource, typeaheadResultsDelegate: UITableViewDelegate) {
        self.emptyResultsDataSource = emptyResultsDataSource
        self.emptyResultsDelegate = emptyResultsDelegate
        self.typeaheadResultsDataSource = typeaheadResultsDataSource
        self.typeaheadResultsDelegate = typeaheadResultsDelegate
        
        searchBar = UISearchBar(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, searchBarHeight))
        emptyResultsTableView = UITableView(frame: CGRectMake(0, searchBarHeight, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height - searchBarHeight), style: .Plain)
        typeaheadResultsTableView = UITableView(frame: CGRectMake(0, searchBarHeight, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height - searchBarHeight), style: .Plain)
        state = .Empty
        super.init(nibName: nil, bundle: nil)
        searchBar.delegate = self
        self.modalPresentationStyle = UIModalPresentationStyle.OverCurrentContext
        self.modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.whiteColor()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        emptyResultsTableView.translatesAutoresizingMaskIntoConstraints = false
        emptyResultsTableView.dataSource = emptyResultsDataSource
        emptyResultsTableView.delegate = emptyResultsDelegate
        view.addSubview(emptyResultsTableView)
        emptyResultsTableView.reloadData()
        
        typeaheadResultsTableView.translatesAutoresizingMaskIntoConstraints = false
        typeaheadResultsTableView.dataSource = typeaheadResultsDataSource
        typeaheadResultsTableView.delegate = typeaheadResultsDelegate
        view.addSubview(typeaheadResultsTableView)
        typeaheadResultsTableView.reloadData()
        
        // Set up constraints
        let viewsDictionary: [String: AnyObject] = ["searchBar": searchBar, "emptyResultsTableView": emptyResultsTableView, "typeaheadResultsTableView": typeaheadResultsTableView, "topGuide": topLayoutGuide, "bottomGuide": bottomLayoutGuide]
        let searchBarHorizontalContraints = NSLayoutConstraint.constraintsWithVisualFormat("|[searchBar]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        let emptyVerticalContraints = NSLayoutConstraint.constraintsWithVisualFormat("V:|[topGuide][searchBar][emptyResultsTableView][bottomGuide]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        let emptyHorizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("|[emptyResultsTableView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        let typeaheadVerticalContraints = NSLayoutConstraint.constraintsWithVisualFormat("V:[searchBar][typeaheadResultsTableView][bottomGuide]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        let typeaheadHorizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("|[typeaheadResultsTableView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        
        // Adding one by one as adding them all together seems to make the compiler take lot longer to compile, at least on Xcode 7 beta.
        var allConstraints = searchBarHorizontalContraints + emptyVerticalContraints
        allConstraints += emptyHorizontalConstraints
        allConstraints += typeaheadVerticalContraints
        allConstraints += typeaheadHorizontalConstraints
        view.addConstraints(allConstraints)
        
        updateViewsForCurrentState()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Handle keyboard changes
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillShow:"), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillHide:"), name: UIKeyboardWillHideNotification, object: nil)
        
        searchBar.becomeFirstResponder()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: Utilities
    
    func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        
        guard let keyboardSize = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() else {
            return
        }
        
        let contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0)
        self.updateViewsToInsets(contentInsets)
    }
    
    func keyboardWillHide(notification: NSNotification) {
        self.updateViewsToInsets(UIEdgeInsetsZero)
    }
    
    func updateViewsToInsets(insets: UIEdgeInsets) {
        emptyResultsTableView.contentInset = insets
        emptyResultsTableView.scrollIndicatorInsets = insets
        
        typeaheadResultsTableView.contentInset = insets
        typeaheadResultsTableView.scrollIndicatorInsets = insets
    }
    
    func updateViewsForCurrentState() {
        switch state {
        case .Empty:
            view.bringSubviewToFront(emptyResultsTableView)
        case .Typeahead:
            view.bringSubviewToFront(typeaheadResultsTableView)
        }
    }
    
    // MARK: UISearchBarDelegate
    // Piping all calls to searchBarDelegate while also implementing the relevant ones for required behavior
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
        searchBarDelegate?.searchBarTextDidBeginEditing?(searchBar)
    }

    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
        if let should = searchBarDelegate?.searchBarShouldBeginEditing?(searchBar) {
            return should
        }
        
        return true
    }
    
    func searchBarShouldEndEditing(searchBar: UISearchBar) -> Bool {
        if let should = searchBarDelegate?.searchBarShouldEndEditing?(searchBar) {
            return should
        }
        
        return true
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        searchBarDelegate?.searchBarTextDidEndEditing?(searchBar)
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.characters.count == 0 {
            state = .Empty
        } else {
            state = .Typeahead
        }
        
        emptyResultsTableView.reloadData()
        typeaheadResultsTableView.reloadData()
        updateViewsForCurrentState()
        
        searchBarDelegate?.searchBar?(searchBar, textDidChange: searchText)
    }
    
    func searchBar(searchBar: UISearchBar, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        if let should = searchBarDelegate?.searchBar?(searchBar, shouldChangeTextInRange: range, replacementText: text) {
            return should
        }
        
        return true
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBarDelegate?.searchBarSearchButtonClicked?(searchBar)
    }
    
    func searchBarBookmarkButtonClicked(searchBar: UISearchBar) {
        searchBarDelegate?.searchBarBookmarkButtonClicked?(searchBar)
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.text = ""
        searchBar.showsCancelButton = false
        state = .Empty
        
        emptyResultsTableView.reloadData()
        typeaheadResultsTableView.reloadData()
        updateViewsForCurrentState()
        
        if let searchBarDelegate = searchBarDelegate {
            searchBarDelegate.searchBarCancelButtonClicked?(searchBar)
        } else {
            self.presentingViewController?.dismissViewControllerAnimated(true, completion: {})
        }
    }
    
    func searchBarResultsListButtonClicked(searchBar: UISearchBar) {
        searchBarDelegate?.searchBarResultsListButtonClicked?(searchBar)
    }
    
    func searchBar(searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        searchBarDelegate?.searchBar?(searchBar, selectedScopeButtonIndexDidChange: selectedScope)
    }
}

