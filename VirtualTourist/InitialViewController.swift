//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Quynh Tran on 20/03/2016.
//  Copyright © 2016 Quynh. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class InitialViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {

    
    @IBOutlet var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        self.mapView.delegate = self
        configUI()
        
        // Fetch
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        
        // set the fetchedResultsControllerDelegate to self
        fetchedResultsController.delegate = self
        
        fetchPins()
    }
    
    override func viewWillDisappear(animated: Bool) {
        
        let mapDetails = NSUserDefaults.standardUserDefaults()
        let latitude = Float(mapView.centerCoordinate.latitude)
        let longitude = Float(mapView.centerCoordinate.longitude)
        let latitudeDelta = Float(mapView.region.span.latitudeDelta)
        let longitudeDelta = Float(mapView.region.span.longitudeDelta)
        
        mapDetails.setValue(latitude, forKey: "latitude")
        mapDetails.setValue(longitude, forKey: "longitude")
        mapDetails.setValue(latitudeDelta, forKey: "latitudeDelta")
        mapDetails.setValue(longitudeDelta, forKey: "longitudeDelta")

        print("SAVED: lat: \(latitude), long: \(longitude), latD: \(latitudeDelta), longD: \(longitudeDelta)")
    }
    
    override func viewDidDisappear(animated: Bool) {
        fetchedResultsController.delegate = nil
    }
    
    // %%%%%%%%%%%%%%%        Core Data variables       %%%%%%%%%%%%%%
    
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
    // %%%%%%%%%%%%%%%        Map View config and Pin methods       %%%%%%%%%%%%%%
    
    func configUI()  {
        
        //get user defaults
        let mapDetails = NSUserDefaults.standardUserDefaults()
        var latitude = mapDetails.doubleForKey("latitude")
        var longitude = mapDetails.doubleForKey("longitude")
        var latitudeDelta = mapDetails.doubleForKey("latitudeDelta")
        var longitudeDelta = mapDetails.doubleForKey("longitudeDelta")
        
        print("RETRIVED: lat: \(latitude), long: \(longitude), latD: \(latitudeDelta), longD: \(longitudeDelta)")
        
        if (latitude * longitude == 0) {
            
            latitude = 51.5072
            longitude = 0.1275
            latitudeDelta = 0.5
            longitudeDelta = 0.5
        }
        
        //MKCoordinateSpanMake
        //MKCoordinateRegionMake
        //CLLocationCoordinate2DMake
        var span = MKCoordinateSpan()
        span.latitudeDelta = latitudeDelta / 3.0
        span.longitudeDelta = longitudeDelta / 3.0
        var region = MKCoordinateRegion()
        region.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        region.span = span
        
        mapView.setRegion(region, animated: true)
        
        //Add long press gesture recognizer
        let longPress = UILongPressGestureRecognizer(target: self, action: "addPin:")
        longPress.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(longPress)
        
    }
    
    func fetchPins() {
        
        //get fetched results
        let pins : [Pin]? = fetchedResultsController.fetchedObjects as? [Pin]
        
        //create pins
        if let pins = pins {
            for currentPin in pins {
                
                let lat = CLLocationDegrees(currentPin.latitude) //TODO: handle errors here!
                let long = CLLocationDegrees(currentPin.longitude)
                
                let newAnotation = MKPointAnnotation()
                newAnotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                newAnotation.title = currentPin.id
                
                //add pin to map
                self.mapView.addAnnotation(newAnotation)
            }
        }
    }

    func addPin(gestureRecognizer:UIGestureRecognizer) {
        
        if gestureRecognizer.state == UIGestureRecognizerState.Began {
        
            let touchPoint = gestureRecognizer.locationInView(self.mapView)
            let newCoord:CLLocationCoordinate2D = mapView.convertPoint(touchPoint, toCoordinateFromView: self.mapView)
        
            let id = Pin.generateID()
            //Add pin to view
            let newAnotation = MKPointAnnotation()
            newAnotation.coordinate = newCoord
            newAnotation.title = id
            mapView.addAnnotation(newAnotation)
        
            //Persist pin
            let dictionary: [String : AnyObject] = [
                Pin.Keys.ID : id,
                Pin.Keys.Latitude : newAnotation.coordinate.latitude,
                Pin.Keys.Longitude : newAnotation.coordinate.longitude
            ]
            
            //Create prive context as child of main context
            let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            privateContext.parentContext = sharedContext
            
            privateContext.performBlockAndWait {

                let _ = Pin(dictionary: dictionary, context: privateContext)
            }
            
            do {
                //Save privateContext will move changes to to main queue
                print("save privateContext")
                try privateContext.save()
            } catch {
                fatalError("Failure to save context: \(error)")
            }
        
            print("New pin added to Core Data")
            
            print("save shared context")
            CoreDataStackManager.sharedInstance().saveContext()
        }
        
    }
    
    // %%%%%%%%%%%%%%%        Map View Protocols       %%%%%%%%%%%%%%
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            if #available(iOS 9.0, *) {
                pinView!.pinTintColor = UIColor.purpleColor()
            } else {
                // Fallback on earlier versions
            }
            pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        mapView.deselectAnnotation(view.annotation! , animated: true)
        
        let id = view.annotation?.title!
        
        //fetch pin entity from core data
        let fetchPin = NSFetchRequest(entityName: "Pin")
        fetchPin.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        let pred = NSPredicate(format: "id == %@", id!)
        fetchPin.predicate = pred
        
        let fetchedPinResultsController = NSFetchedResultsController(fetchRequest: fetchPin,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        // Fetch
        do {
            try fetchedPinResultsController.performFetch()
        } catch {}
        
        if (fetchedPinResultsController.fetchedObjects!.count > 0) {
            let pin = fetchedPinResultsController.fetchedObjects![0] as? Pin
            
            let controller = self.storyboard?.instantiateViewControllerWithIdentifier("LocationVC") as! LocationViewController
            controller.thisPin = pin
            
            self.navigationController?.pushViewController(controller, animated: true)
            
        }
        
    }
    
    func mapView(mapView: MKMapView, didAddAnnotationViews views: [MKAnnotationView]) {
        
        for annotation in views {
            
            let endFrame = annotation.frame
            annotation.frame = CGRectOffset(endFrame, 0, -500)
            
            UIView.animateWithDuration(1, animations: {
            
                annotation.frame = endFrame
                
            })
            
        }
        
    }
    

}

