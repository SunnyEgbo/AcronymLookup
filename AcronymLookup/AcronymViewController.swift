//
//  AcronymViewController.swift
//  AcronymLookup
//
//  Created by Sunny Egbo on 3/10/17.
//  Copyright © 2017 Sunny Egbo. All rights reserved.
//

import UIKit
import MBProgressHUD


enum AcronymParameter: String
{
    case sf, lf
}


public enum AcronymError: Error {
    case noResult, missingTerm, invalidFormat, invalidParameter
}

extension AcronymError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noResult:
            return NSLocalizedString("There are no result for this search.", comment: "Not Found Error")
        case .missingTerm:
            return NSLocalizedString("A valid acronym or initial is required.", comment: "Missing Term Error")
        case .invalidFormat:
            return NSLocalizedString("The correct format for searches is 'param=<term>'.", comment: "Format Error")
        case .invalidParameter:
            return NSLocalizedString("Valid parameters are 'sf' for the abbreviation for which definitions are to be retrieved or 'lf' for fullforms for which abbreviations are to be retrieved.", comment: "Parameter Error")
        }
    }
    public var title: String? {
        switch self {
        case .noResult:
            return NSLocalizedString("Not Found Error", comment: "Not Found Error")
        case .missingTerm:
            return NSLocalizedString("Missing Term Error", comment: "Missing Term Error")
        case .invalidFormat:
            return NSLocalizedString("Format Error", comment: "Format Error")
        case .invalidParameter:
            return NSLocalizedString("Parameter Error", comment: "Parameter Error")
        }
    }
}

private let cellIdentifier = "acronym cell"
let iPhone5Width: CGFloat = 320.0
let iPhone6Width: CGFloat = 375.0


class AcronymViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate
{
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Private

    fileprivate var resultType = AcronymParameter.sf
    fileprivate var result: [[String: AnyObject]]?
    fileprivate var longForms: [LongForm]?
    
    
    // MARK: - ViewController LifeCycle

    override func viewDidLoad() {
        super.viewDidLoad()

        searchBar.tintColor = .white
        navigationController?.navigationBar.barTintColor = UIColor(red: 40.0/255.0, green: 140.0/255.0, blue: 180.0/255.0, alpha: 1.0)
        navigationController?.navigationBar.tintColor = .white
    }

    override var preferredStatusBarStyle : UIStatusBarStyle
    {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let longForms = longForms else { return 0 }
        
        return longForms.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let longForms = longForms, let variations = longForms[section].variations else { return 0 }
        
        return variations.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let lf = longForms?[section] {
            return lf.description
        }
        return ""
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    {
        var title = String()
        
        if let lf = longForms?[section] {
            title = lf.description
        }
        else {
            title = ""
        }
        
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.attributedText = customSectionTitleStringForText(title)
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        
        if let variations = longForms?[indexPath.section].variations, let lfCell = cell as? LongFormTableViewCell {
            let variation = variations[indexPath.row]
            lfCell.titleLabel?.text = variation.description
        }
        
        return cell
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        dismissKeyboard()
        longForms = nil
        title = ""
        tableView.reloadData()
        if let searchTerm = validSearchTerm(searchBar.text) {
            fetchDefinition(for: searchTerm)
        }
    }
    
    
    // MARK: - Private
    
    // MARK: -- Keyboard dismissal
    
    fileprivate func dismissKeyboard() {
        searchBar.resignFirstResponder()
    }
    
    
    fileprivate func validSearchTerm(_ term: String?) -> String?
    {
        // Make sure that the search term is not an empty string
        var searchTerm = term?.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .punctuationCharacters).lowercased()
        guard let nonEmptyTerm = searchTerm, !nonEmptyTerm.isEmpty else {
            let error = AcronymError.missingTerm as NSError
            showFailureAlert(with: error)
            return nil
        }
        
        guard let termComponents = searchTerm?.components(separatedBy: "="), termComponents.count > 1, let abbrev = termComponents.last, !abbrev.isEmpty else {
            let error = AcronymError.invalidFormat as NSError
            showFailureAlert(with: error)
            return nil
        }
        
        // Encode the search
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;"
        let allowedCharacterSet = (CharacterSet.urlQueryAllowed as NSCharacterSet).mutableCopy() as! NSMutableCharacterSet
        allowedCharacterSet.removeCharacters(in: generalDelimitersToEncode + subDelimitersToEncode)
        searchTerm = searchTerm?.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet as CharacterSet)
        if let searchTerm = searchTerm {
            return searchTerm
        }
        return nil
    }
    
    
    fileprivate func fetchDefinition(for searchTerm: String) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let spinnerActivity = MBProgressHUD.showAdded(to: self.view, animated: true)
        spinnerActivity.label.text = "Sending ..."
        spinnerActivity.detailsLabel.text = "Please Wait!!"
        spinnerActivity.isUserInteractionEnabled = false
        APIServer.shared.definitions(forAcronym: searchTerm, withCompletion: { [weak self] (success, results, error) in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            spinnerActivity.hide(animated: true)
            if success {
                if let result = results?.first as? [String: AnyObject] {
                    self?.title = searchTerm
                    self?.displayDefinitions(result)
                }
                else {
                    let error = AcronymError.noResult as NSError
                    self?.showFailureAlert(with: error)
                }
            }
            else {
                self?.showFailureAlert(with: error)
            }
        })
    }

    
    fileprivate func displayDefinitions(_ definitions: [String: AnyObject]) {
        guard let _ = definitions["sf"] as? String, let lfs = definitions["lfs"] as? [[String: AnyObject]] else {
            showFailureAlert(with: nil)
            return
        }
        
        longForms = [LongForm]()
        for longformInfo in lfs {
            if let longForm = LongForm(longformInfo) {
                longForms?.append(longForm)
            }
        }
        tableView.reloadData()
    }
    
    
    fileprivate func customSectionTitleStringForText(_ text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string:text)
        let textLength = attributedString.length
        let paragraphStyle = NSMutableParagraphStyle()
        let deviceWidth = UIScreen.main.bounds.size.width
        if deviceWidth < iPhone6Width {
            attributedString.addAttribute(NSFontAttributeName, value: UIFont(name: "AvenirNext-Medium", size: 13.0)!, range: NSRange(location: 0, length: textLength ))
        }
        else {
            attributedString.addAttribute(NSFontAttributeName, value: UIFont(name: "AvenirNext-Medium", size: 15.0)!, range: NSRange(location: 0, length: textLength ))
        }
        paragraphStyle.lineSpacing = -0.30
        attributedString.addAttribute(NSForegroundColorAttributeName, value: UIColor.black, range: NSRange(location: 0, length: textLength ))
        attributedString.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSRange(location: 0, length: textLength ))
        
        return attributedString
    }

    
    fileprivate func showFailureAlert(with error: Error?) {
        var title = "Error"
        var message = "Request failed with unknown error."
        if let error = error {
            message = error.localizedDescription
            if let error = error as? AcronymError {
                title = error.title!
            }
        }
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert
        )
        
        alert.addAction(UIAlertAction(title: "Ok",
                                      style: UIAlertActionStyle.cancel,
                                      handler: { (action) in
                                        //
        }))

        self.present(alert, animated: true) {
        }
    }
}
