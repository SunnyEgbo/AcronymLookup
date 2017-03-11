//
//  AcronymRequest.swift
//  AcronymLookup
//
//  Created by Sunny Egbo on 3/10/17.
//  Copyright © 2017 Sunny Egbo. All rights reserved.
//

import Foundation

class AcronymRequest: NSObject
{
    var acronym: String
    var completion: ((Bool, [AnyObject]?, Error?) -> Void)?
    var dataTask: URLSessionDataTask?
    
    // Request result
    var httpResponseCode: Int?
    var isResultValid = false
    var error: Error?
    var result: [AnyObject]?
    
    
    init(_ acronym: String)
    {
        self.acronym = acronym
    }

}

