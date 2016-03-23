//
//  Pin.swift
//  VirtualTourist
//
//  Created by Quynh Tran on 20/03/2016.
//  Copyright © 2016 Quynh. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class Pin : NSManagedObject {
    
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
        static let Images = "images"
        static let ID = "id"
    }
    
    @NSManaged var latitude : Float
    @NSManaged var longitude : Float
    @NSManaged var id : String
    @NSManaged var images : [Image]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        // Core Data
        let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // Dictionary
        let lat = dictionary[Keys.Latitude]
        let long = dictionary[Keys.Longitude]
        let latFloat = Float(lat! as! NSNumber)
        let longFloat = Float(long! as! NSNumber)
        self.latitude = latFloat
        self.longitude = longFloat
        self.id = dictionary[Keys.ID] as! String
        
       
    }
    
    //for generating id number
    
    class func generateID() -> String {
        let newID = NSUUID().UUIDString
        return newID
    }
    
}