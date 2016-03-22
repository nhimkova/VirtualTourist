//
//  LocationViewController.swift
//  VirtualTourist
//
//  Created by Quynh Tran on 20/03/2016.
//  Copyright © 2016 Quynh. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class LocationViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    
    
    @IBOutlet var smallMapView: MKMapView!
    
    @IBOutlet var collectionView: UICollectionView!
    
    var thisPin : Pin?

    var selectedIndexes = [NSIndexPath]()
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configMap()
        
        // Step 2: Perform the fetch
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        
        // Step 6: Set the delegate to this view controller
        fetchedResultsController.delegate = self
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if thisPin!.images == [] {
            searchFlickr()
        }
    }
    
    // %%%%%%%%%%%%%%%      Flickr download     %%%%%%%%%%%%%%%%%
    
    func searchFlickr() {
        
        FlickrClient.sharedInstance().taskForImageSearch((thisPin?.latitude)!, longitude: (thisPin?.longitude)!) { (result, error) in
            
            if (error != nil) {
                
                print("flickr error")
                
            } else {
                
                if let photosDictionary = result.valueForKey("photos") as? [String : AnyObject] {
                    //find number of pages
                    if let pagesInt = photosDictionary["pages"] as? Int {
                        
                        let pages = UInt32(pagesInt)
                        
                        //generage random page number
                        let randomPage = arc4random_uniform(pages) + 1
                        print("Random page: \(randomPage)")
                            
                        //get images for page
                        FlickrClient.sharedInstance().taskForImagesAtPage( (self.thisPin?.latitude)!, longitude: (self.thisPin?.longitude)!, page: Int(randomPage) ) { (JSONresult, error) in
                        
                            if (error != nil) {
                                
                                print("flickr image at page error")
                                
                            } else {
                                if let photosDictionary = JSONresult.valueForKey("photos") as? [String : AnyObject] {
                                    if let photos = photosDictionary["photo"] as? [[String : AnyObject]] {
                                        
                                        let _ = photos.map() { (dictionary: [String : AnyObject]) -> Image in
                                            
                                            let image = Image(dictionary: dictionary, context: self.sharedContext)
                                            image.pin = self.thisPin
                                            return image
                                        }
                                        
                                    } // if let photos
                                    
                                    // Update the collection view on the main thread
                                    dispatch_async(dispatch_get_main_queue()) {
                                        self.collectionView.reloadData()
                                    }

                                } // photosDictionary
                                
                            } //else if no error
                        
                        } // taskForImagesAtPage
                        
                    } //pagesString
                
                } //photosDictionary
                
            } //else if no error
            
        } //taskForImageSearch
        
        
    }
    
    // %%%%%%%%%%%%%%%      UI config        %%%%%%%%%%%%%%%
    
    func configMap() {
        
        //set region
        let regionRadius: CLLocationDistance = 1000 //Userdefaults
        
        let lat = CLLocationDegrees(thisPin!.latitude) //TODO: handle errors here!
        let long = CLLocationDegrees(thisPin!.longitude)
        
        let newAnotation = MKPointAnnotation()
        newAnotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        newAnotation.title = "I am here!"
        
        //add pin to map
        self.smallMapView.addAnnotation(newAnotation)
        
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(newAnotation.coordinate,
            regionRadius * 2.0, regionRadius * 2.0)
        smallMapView.setRegion(coordinateRegion, animated: true)
        
    }
    
    // %%%%%%%%%%%%%%%        New Collection       %%%%%%%%%%%%%%
    
    @IBAction func didPushNewCollection(sender: AnyObject) {
        
        //delete old images in core data
        for item in fetchedResultsController.fetchedObjects as! [Image] {
            sharedContext.deleteObject(item)
        }
        
        collectionView.reloadData()
        
        searchFlickr()
        
    }
    
    
    // %%%%%%%%%%%%%%%        Core Data variables       %%%%%%%%%%%%%%
    
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Image")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.thisPin!);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
    }()

    
    // %%%%%%%%%%%%%%%      CollectionView protocols      %%%%%%%%%%%%%%%
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        
        let sections = self.fetchedResultsController.sections?.count ?? 0
        
        return sections
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ImageCell", forIndexPath: indexPath) as! ImageCollectionViewCell
        
        let image = fetchedResultsController.objectAtIndexPath(indexPath) as! Image
        
        configCell(cell, image: image)
        
        return cell
    }
    
    func configCell(cell: ImageCollectionViewCell, image: Image) {
        
        cell.activityIndicator.hidden = true
        
        if (image.flickrResult != nil) {
            
            dispatch_async(dispatch_get_main_queue(), {
                
                cell.imageView.image = image.flickrResult
            })
            
        } else {
        
            cell.activityIndicator.startAnimating()
            cell.activityIndicator.hidden = false
        
            FlickrClient.sharedInstance().taskForDownloadImage(image.url) { (flickrImage, error) in
            
                if let error = error {
                    //cannot download
                    print(error)
                    
                } else {
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        
                        image.flickrResult = flickrImage
                        cell.imageView.image = flickrImage
                        cell.activityIndicator.hidden = true
                        cell.activityIndicator.stopAnimating()
                    })
                }
            }
        }
        
    }
    
    // %%%%%%%%%%%%%%%      NSFetchedResultsController protocols      %%%%%%%%%%%%%%%
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    
    func controller(controller: NSFetchedResultsController,
        didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
        atIndex sectionIndex: Int,
        forChangeType type: NSFetchedResultsChangeType) {
            
            print("Did change section.")
            switch type {
            case .Insert:
                
                self.collectionView.insertSections(NSIndexSet(index: sectionIndex))
                
            case .Delete:
                self.collectionView.deleteSections(NSIndexSet(index: sectionIndex))
                
            default:
                return
            }
    }
    
    //
    func controller(controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            
            switch type{
                
            case .Insert:
                print("Inserting an item")
                insertedIndexPaths.append(newIndexPath!)
                break
            case .Delete:
                print("Deleting an item")
                deletedIndexPaths.append(indexPath!)
                break
            case .Update:
                print("Updating an item.")
                updatedIndexPaths.append(indexPath!)
                updatedIndexPaths.append(newIndexPath!)
                break
            case .Move:
                print("Moving an item.")
                break
            }

    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    

}
