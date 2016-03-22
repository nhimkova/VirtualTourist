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
    
    
    @IBOutlet var toolBarButton: UIBarButtonItem!
    
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
                    
                    if let photos = photosDictionary["photo"] as? [[String : AnyObject]] {
                        
                        //Select random photos
                        var selectedPhotos : [[String : AnyObject]] = []
                        print("Total photos: \(photos.count)")
                        let count = min(photos.count, 21)
                        
                        for _ in 0...count {
                            let randomPhotoIndex = Int(arc4random_uniform(UInt32(photos.count)))
                            
                            selectedPhotos.append(photos[randomPhotoIndex])
                            
                        }
                        
                        let _ = selectedPhotos.map() { (dictionary: [String : AnyObject]) -> Image in
                                            
                            let image = Image(dictionary: dictionary, context: self.sharedContext)
                            image.pin = self.thisPin
                            return image
                        }
                                        
                    } // if let photos

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
    
    // %%%%%%%%%%%%%%%        New Collection  / Delete photos    %%%%%%%%%%%%%%
    
    @IBAction func didPushNewCollection(sender: AnyObject) {
        
        //delete selected photos
        if (selectedIndexes.count > 0) {
            
            var selectedImages : [Image] = []
            
            for indexPath in selectedIndexes {
                
                let selectedImage = fetchedResultsController.objectAtIndexPath(indexPath) as! Image
                selectedImages.append(selectedImage)
                
                // Delete Images on the local disk
                print("URL to REMOVE: \(selectedImage.url)")
                
                let path = FlickrClient.Caches.imageCache.pathForIdentifier(selectedImage.url)

                do {
                    try NSFileManager.defaultManager().removeItemAtPath(path)
                }
                catch let error as NSError {
                    print("Cannot delete file at path \(path) because \(error)")
                }
                
            }
            
            for item in selectedImages {
                sharedContext.deleteObject(item)
                toolBarButton.title = "New Collection"
            }
            
            selectedIndexes = [NSIndexPath]()
            //collectionView.reloadData()
            CoreDataStackManager.sharedInstance().saveContext()
            
        } else {
        
            //delete all images in core data
            for item in fetchedResultsController.fetchedObjects as! [Image] {
                sharedContext.deleteObject(item)
            }
            
            CoreDataStackManager.sharedInstance().saveContext()
            
            collectionView.reloadData()
        
            searchFlickr()
        }
        
        
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
        
        if let _ = selectedIndexes.indexOf(indexPath) {
            cell.overlay.hidden = false
            cell.bringSubviewToFront(cell.overlay)
            cell.overlay.alpha = 0.8
        } else {
            cell.overlay.hidden = true
        }
        
        let image = fetchedResultsController.objectAtIndexPath(indexPath) as! Image
        
        configCell(cell, image: image)
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
            
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! ImageCollectionViewCell
        
        if let index = selectedIndexes.indexOf(indexPath) {
            selectedIndexes.removeAtIndex(index)
            cell.overlay.hidden = true
        } else {
            selectedIndexes.append(indexPath)
            cell.overlay.hidden = false
            cell.bringSubviewToFront(cell.overlay)
            cell.overlay.alpha = 0.8
        }
        
        //Change UI
        if (selectedIndexes.count > 0) {
            
            toolBarButton.title = "Delete Selected Photos"
            
        } else {
            
            toolBarButton.title = "New Collection"
        }
            
    }
    
    func configCell(cell: ImageCollectionViewCell, image: Image) {
        
        cell.imageView.layer.cornerRadius = 6
        cell.imageView.clipsToBounds = true
        cell.imageView.hidden = false
        cell.imageView.alpha = 1
        cell.imageView.image = UIImage(named: "placeholder")
        
        cell.activityIndicator.hidden = true
        
        if (image.flickrResult != nil) {
            
            dispatch_async(dispatch_get_main_queue(), {
                
                cell.imageView.image = image.flickrResult
            })
            
        } else {
            
            cell.bringSubviewToFront(cell.activityIndicator)
            cell.activityIndicator.startAnimating()
            cell.activityIndicator.hidden = false
        
            FlickrClient.sharedInstance().taskForDownloadImage(image.url) { (flickrImage, error) in
            
                if let error = error {
                    //cannot download
                    print(error)
                    
                } else {
                    
                    dispatch_async(dispatch_get_main_queue(), {
                    
                        self.toolBarButton.title = "New Collection"
                        
                        image.flickrResult = flickrImage
                        CoreDataStackManager.sharedInstance().saveContext()
                        
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
                //updatedIndexPaths.append(newIndexPath!)
                break
            case .Move:
                print("Moving an item.")
                break
            }

    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                print("insertItem in controllerDidChangeContent")
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
        
            for indexPath in self.deletedIndexPaths {
                print("deleteItem in controllerDidChangeContent")
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
        
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
        
            }, completion: { (success) -> Void in
                
                if (success) {
                    print("success")
                    self.insertedIndexPaths = [NSIndexPath]()
                    self.deletedIndexPaths = [NSIndexPath]()
                    self.updatedIndexPaths = [NSIndexPath]()
                    
                }
                
        })
    }
    

}
