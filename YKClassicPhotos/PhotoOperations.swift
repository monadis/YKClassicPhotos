//
//  PhotoOperations.swift
//  ClassicPhotos
//
//  Created by LYH on 11/3.
//  Copyright © 2015년 raywenderlich. All rights reserved.
//

import UIKit

// This enum contains all the possible states a photo record can be in
enum PhotoRecordState {
	case New, Downloaded, Filtered, Failed
}

class PhotoRecord {
	let name:String
	let url:NSURL
	var state = PhotoRecordState.New
	var image = UIImage(named: "Placeholder")

	init(name:String, url:NSURL) {
		self.name = name
		self.url = url
	}
}

class PendingOperations {
	lazy var downloadsInProgress = [NSIndexPath:NSOperation]()
	lazy var downloadQueue:NSOperationQueue = {
		var queue = NSOperationQueue()
		queue.name = "Download queue"
		queue.maxConcurrentOperationCount = 1	// 테스트의 편의상 쓰레드는 한개로 제한한다. 실사용한다면 이 줄을 지우는게 퍼포먼스에 더 좋다.
		return queue
	}()

	lazy var filtrationsInProgress = [NSIndexPath:NSOperation]()
	lazy var filtrationQueue:NSOperationQueue = {
		var queue = NSOperationQueue()
		queue.name = "Image Filtration queue"
		queue.maxConcurrentOperationCount = 1	// 테스트의 편의상 쓰레드는 한개로 제한한다. 실사용한다면 이 줄을 지우는게 퍼포먼스에 더 좋다.
		return queue
	}()
}


class DownloadOperation: NSOperation {
	//1
	let photoRecord: PhotoRecord

	//2
	init(photoRecord: PhotoRecord) {
		self.photoRecord = photoRecord
	}

	//3
	override func main() {
		//4
		if self.cancelled {
			return
		}
		//5
		let imageData = NSData(contentsOfURL:self.photoRecord.url)

		//6
		if self.cancelled {
			return
		}

		//7
		if imageData?.length > 0 {
			self.photoRecord.image = UIImage(data:imageData!)
			self.photoRecord.state = .Downloaded
		}
		else
		{
			self.photoRecord.state = .Failed
			self.photoRecord.image = UIImage(named: "Failed")
		}
	}
}


class FilterOperation: NSOperation {
	let photoRecord: PhotoRecord

	init(photoRecord: PhotoRecord) {
		self.photoRecord = photoRecord
	}

	override func main () {
		if self.cancelled {
			return
		}

		if self.photoRecord.state != .Downloaded {
			return
		}

		if let filteredImage = self.applySepiaFilter(self.photoRecord.image!) {
			self.photoRecord.image = filteredImage
			self.photoRecord.state = .Filtered
		}
	}


	func applySepiaFilter(image:UIImage) -> UIImage? {
		let inputImage = CIImage(data:UIImagePNGRepresentation(image)!)

		if self.cancelled {
			return nil
		}
		let context = CIContext(options:nil)
		let filter = CIFilter(name:"CISepiaTone")
		filter!.setValue(inputImage, forKey: kCIInputImageKey)
		filter!.setValue(0.8, forKey: "inputIntensity")
		let outputImage = filter!.outputImage

		if self.cancelled {
			return nil
		}

		let outImage = context.createCGImage(outputImage!, fromRect: outputImage!.extent)
		let returnImage = UIImage(CGImage: outImage)
		return returnImage
	}
	
}


