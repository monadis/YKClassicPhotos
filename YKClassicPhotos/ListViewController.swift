//
//  ListViewController.swift
//  ClassicPhotos
//
//  Created by Richard Turton on 03/07/2014.
//  Copyright (c) 2014 raywenderlich. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceURL = NSURL(string:"https://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ListViewController: UITableViewController,NSURLSessionDelegate {

	var photos = [PhotoRecord]()
	let pendingOperations = PendingOperations()

	override func viewDidLoad() {
		super.viewDidLoad()
		self.title = "Classic Photos"
		fetchPhotoDetails()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// #pragma mark - Table view data source

	override func tableView(tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
		return photos.count
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("CellIdentifier", forIndexPath: indexPath)

		if cell.accessoryView == nil {
			let indicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
			cell.accessoryView = indicator
		}
		let indicator = cell.accessoryView as! UIActivityIndicatorView

		let photoDetails = photos[indexPath.row]

		cell.textLabel?.text = photoDetails.name
		cell.imageView?.image = photoDetails.image

		switch (photoDetails.state){
		case .Filtered:
			indicator.stopAnimating()
		case .Failed:
			indicator.stopAnimating()
			cell.textLabel?.text = "Failed to load"
		case .New, .Downloaded:
			indicator.startAnimating()
			if (!tableView.dragging && !tableView.decelerating) {
				self.startOperationsForPhotoRecord(photoDetails,indexPath:indexPath)
			}
		}
		return cell
	}

	override func scrollViewWillBeginDragging(scrollView: UIScrollView) {
	  suspendAllOperations()
	}

	override func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
	  if !decelerate {
		loadImagesForOnscreenCells()
		resumeAllOperations()
	  }
	}

	override func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
	  loadImagesForOnscreenCells()
	  resumeAllOperations()
	}

	func suspendAllOperations () {
	  pendingOperations.downloadQueue.suspended = true
	  pendingOperations.filtrationQueue.suspended = true
	}

	func resumeAllOperations () {
	  pendingOperations.downloadQueue.suspended = false
	  pendingOperations.filtrationQueue.suspended = false
	}

	func loadImagesForOnscreenCells () {
	  //1
	  if let pathsArray = tableView.indexPathsForVisibleRows {
		//2
		var allPendingOperations = Set(pendingOperations.downloadsInProgress.keys.elements)
		allPendingOperations.unionInPlace(pendingOperations.filtrationsInProgress.keys.elements)

		//3
		var toBeCancelled = allPendingOperations
		let visiblePaths = Set(pathsArray )
		toBeCancelled.subtractInPlace(visiblePaths)

		//4
		var toBeStarted = visiblePaths
		toBeStarted.subtractInPlace(allPendingOperations)

		// 5
		for indexPath in toBeCancelled {
			if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
				pendingDownload.cancel()
			}
			pendingOperations.downloadsInProgress.removeValueForKey(indexPath)
			if let pendingFiltration = pendingOperations.filtrationsInProgress[indexPath] {
				pendingFiltration.cancel()
			}
			pendingOperations.filtrationsInProgress.removeValueForKey(indexPath)
		}

		// 6
		for indexPath in toBeStarted {
			let indexPath = indexPath as NSIndexPath
			let recordToProcess = self.photos[indexPath.row]
			startOperationsForPhotoRecord(recordToProcess, indexPath: indexPath)
		}
	  }
	}
	
	func fetchPhotoDetails() {

		UIApplication.sharedApplication().networkActivityIndicatorVisible = true

		let defaultConfigObject = NSURLSessionConfiguration.defaultSessionConfiguration()
		defaultConfigObject.timeoutIntervalForRequest = 1;
		let defaultSession = NSURLSession(configuration: defaultConfigObject, delegate:self , delegateQueue:NSOperationQueue.mainQueue())
		let dataTask = defaultSession.dataTaskWithURL(dataSourceURL!) {
			[unowned self] data,response,error in

			guard error == nil else {
				let alertController = UIAlertController(title: "Oops!", message:error!.localizedDescription, preferredStyle: .Alert)
				alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
				self.presentViewController(alertController, animated: true, completion: nil)

				UIApplication.sharedApplication().networkActivityIndicatorVisible = false
				return
			}

			guard let data = data else {
				let alertController = UIAlertController(title: "Oops!", message:"No error. but received no data! Strange..", preferredStyle: .Alert)
				alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
				self.presentViewController(alertController, animated: true, completion: nil)

				UIApplication.sharedApplication().networkActivityIndicatorVisible = false
				return
			}

			if let datasourceDictionary = try? NSPropertyListSerialization.propertyListWithData(data, options:.Immutable, format: nil) as? NSDictionary  {
				for(key, value) in datasourceDictionary! {
					let name = key as? String
					let url = NSURL(string:value as? String ?? "")
					if name != nil && url != nil {
						let photoRecord = PhotoRecord(name:name!, url:url!)
						self.photos.append(photoRecord)
					}
				}
				print("received PhotoData")
			} else {
				print("NSPropertyListSerialization.propertyListWithData(...) error")
			}

			dispatch_async(dispatch_get_main_queue()) {
				self.tableView.reloadData()
			}
			UIApplication.sharedApplication().networkActivityIndicatorVisible = false

		}
		dataTask.resume()
	}

	func startOperationsForPhotoRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
		switch (photoDetails.state) {
		case .New:
			startDownloadForRecord(photoDetails, indexPath: indexPath)
		case .Downloaded:
			startFiltrationForRecord(photoDetails, indexPath: indexPath)
		default:
			NSLog("do nothing")
		}
	}

	func startDownloadForRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
		guard pendingOperations.downloadsInProgress[indexPath] == nil else {
			return
		}

		let downloader = DownloadOperation(photoRecord: photoDetails)
		downloader.completionBlock = {
			if downloader.cancelled {
				return
			}
			dispatch_async(dispatch_get_main_queue(), {
				self.pendingOperations.downloadsInProgress.removeValueForKey(indexPath)
				self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
			})
		}
		pendingOperations.downloadsInProgress[indexPath] = downloader
		pendingOperations.downloadQueue.addOperation(downloader)
	}

	func startFiltrationForRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
		guard pendingOperations.filtrationsInProgress[indexPath] == nil else {
			return
		}

		let filterer = FilterOperation(photoRecord: photoDetails)
		filterer.completionBlock = {
			if filterer.cancelled {
				return
			}
			dispatch_async(dispatch_get_main_queue(), {
				self.pendingOperations.filtrationsInProgress.removeValueForKey(indexPath)
				self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
			})
		}
		pendingOperations.filtrationsInProgress[indexPath] = filterer
		pendingOperations.filtrationQueue.addOperation(filterer)
	}
}
