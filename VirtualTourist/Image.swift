//
//  Picture.swift
//  VirtualTourist
//
//  Created by Quynh Tran on 20/03/2016.
//  Copyright © 2016 Quynh. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Image : NSManagedObject {
    
    struct Keys {
        static let Name = "id"
        static let URL = "url_m"
        
    }
    
    @NSManaged var name : String
    @NSManaged var url : String
    @NSManaged var path : String
    @NSManaged var pin : Pin?
    
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        // Core Data
        let entity =  NSEntityDescription.entityForName("Image", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // Dictionary
        name = dictionary[Keys.Name] as! String
        url = dictionary[Keys.URL] as! String

        
    }
    
    var flickrResult: UIImage? {
        
        get {
            
            let imageURL = NSURL(fileURLWithPath: url)
            let fileName = imageURL.lastPathComponent
            
            return FlickrClient.Caches.imageCache.imageWithIdentifier(fileName)
        }
        
        set {
            
            let imageURL = NSURL(fileURLWithPath: url)
            let fileName = imageURL.lastPathComponent
            
            print("store image \(fileName!)")
            
            FlickrClient.Caches.imageCache.storeImage(newValue, withIdentifier: fileName!)
        }
    }


    
}