//
//  LongForm.swift
//  AcronymLookup
//
//  Created by Sunny Egbo on 3/10/17.
//  Copyright © 2017 Sunny Egbo. All rights reserved.
//

import Foundation

class LongForm
{
    var name: String
    var frequency: Int
    var since: Int
    var variations: [LongForm]?

    var description: String
    {
        //lf: heavy meromyosin, freq: 267, since: 1971
        return "lf: \(name), freq: \(frequency), since: \(since)"
    }

    
    init?(_ longformInfo: [String: AnyObject]) {
        guard let name = longformInfo["lf"] as? String, let freq = longformInfo["freq"] as? Int, let since = longformInfo["since"] as? Int else {
            return nil
        }
        
        self.name = name
        self.frequency = freq
        self.since = since
        self.variations = [LongForm]()
        
        if let otherVariations = longformInfo["vars"] as? [[String: AnyObject]] {
            for longform in otherVariations {
                if let newLongForm = LongForm(longform) {
                    variations?.append(newLongForm)
                }
            }
        }
    }
        
}
