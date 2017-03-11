//
//  APIServer.swift
//  AcronymLookup
//
//  Created by Sunny Egbo on 3/10/17.
//  Copyright © 2017 Sunny Egbo. All rights reserved.
//

import Foundation


let ENDPOINT_PATH = "http://www.nactem.ac.uk/software/acromine/dictionary.py"


class APIServer: NSObject, URLSessionDataDelegate
{
    static let shared = APIServer()
    
    // A common url session for all acronym requests
    fileprivate lazy var apiSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.sunnyegbo.acronym-server.url.configuration")
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        return session
    }()
    
    // Data structure to keep track of outstanding requests
    // Can be extended to a dictionary if more than one request can be outstanding
    fileprivate var outstandingRequest: AcronymRequest?
    
    
    override init() {
        super.init()
        
        let _ = apiSession
    }
    
    
    // MARK: - Public methods
    
    // Instance method to create and start a urlsession request task
    func definitions(forAcronym acronym: String, withBody body: [String: AnyObject]? = nil, withCompletion completion: ((Bool, [AnyObject]?, Error?) -> Void)?) {
        if let existingAcronymRequest = outstandingRequest {
            // If there is an outstanding request for the same acronym, ignore the new request
            if acronym == existingAcronymRequest.acronym {
                completion?(false, nil, nil)
                return
            }
            // Cancel any outstanding requests if acronym is different from new acronym
            existingAcronymRequest.dataTask?.cancel()
            outstandingRequest = nil
        }
        
        let path = ENDPOINT_PATH+"?\(acronym)"
        
        guard let url = URL(string: path) else {
            completion?(false, nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Track the completion handler, url session task and corresponding http response and result in an AcronymRequest object
        // The urlsession delegate will look into this structure to make sure the response is for this request
        outstandingRequest = AcronymRequest(acronym)
        outstandingRequest?.completion = completion // save the completion handler for urlsession to call at the completion of the url session task
        outstandingRequest?.dataTask = apiSession.dataTask(with: request)
        // Kick off the url request task
        outstandingRequest?.dataTask!.resume()
    }
    
    // Instance method to cancel outstanding urlsession request task
    func cancelCurrentRequest(_ completion: (() -> Void)? = nil)
    {
        if let existingAcronymRequest = outstandingRequest {
            // Cancel any outstanding requests if acronym is different from new acronym
            existingAcronymRequest.dataTask?.cancel()
            outstandingRequest = nil
        }
        completion?()
    }

    class func acronym(within url: URL) -> String?
    {
        return String(describing: url).components(separatedBy: "?").last
    }
    
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let url = dataTask.originalRequest?.url, let acronym = APIServer.acronym(within: url), let dataRequest = outstandingRequest, acronym == dataRequest.acronym else {
            completionHandler(.allow)
            return
        }
        
        // Save the response code in the data request object to be inspected when the data task completes
        if let httpResponse = response as? HTTPURLResponse {
            dataRequest.httpResponseCode = httpResponse.statusCode
            print(httpResponse.statusCode as Any)
        }
        // Call the task completion handler to tell the urlsession to send the data
        completionHandler(.allow)
    }
    
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let url = dataTask.originalRequest?.url, let acronym = APIServer.acronym(within: url), let dataRequest = outstandingRequest, acronym == dataRequest.acronym else { return }
        
        // Save the received data
        do {
            let serialized_data = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
            if let serialized_data = serialized_data as? [AnyObject] {
                dataRequest.result = serialized_data
                dataRequest.isResultValid = true
            }
        }
        catch let error {
            print(error)
            dataRequest.error = error
            dataRequest.isResultValid = false
        }
    }
    
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url, let acronym = APIServer.acronym(within: url), let dataRequest = outstandingRequest, acronym == dataRequest.acronym else { return }
        
        // Call the request's completion handler with the result
        let result = dataRequest.isResultValid ? dataRequest.result : nil
        if let error = error {
            dataRequest.completion?(false, result, error)
        }
        else {
            dataRequest.completion?(true, result, error)
        }
        self.outstandingRequest = nil
    }
    
    
    
}
