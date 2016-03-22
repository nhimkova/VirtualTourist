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
    
        let initialLocation = CLLocation(latitude: 51.5072, longitude: 0.1275) //Userdefaults
        let regionRadius: CLLocationDistance = 1000 //Userdefaults
        
        //Set initial map view
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(initialLocation.coordinate,
            regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
        
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

        let _ = Pin(dictionary: dictionary, context: sharedContext)
        
        print("New pin added to Core Data")
        
        CoreDataStackManager.sharedInstance().saveContext()
        
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
    
    // %%%%%%%%%%%%%%%        NSFetchedResultController Protocols       %%%%%%%%%%%%%%

    
    
    

}

