//: Playground - noun: a place where people can play

import UIKit
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

// Data transfer between two operations
//
//class Op1: NSOperation {
//	let data1 = "data1"
//	override func main() {
//		print("1")
//	}
//}
//
//class Op2: NSOperation {
//	var data2:String?
//	override func main() {
//		print("2")
//		if let a = self.dependencies.first as? Op1 {
//			self.data2 = a.data1
//			print("data2 = \(data2!)")
//		}
//	}
//}
//
//
//let op1 = Op1()
//let op2 = Op2()
//
//op2.addDependency(op1)
//
//let opq = NSOperationQueue()
//
//op1.cancel()
//opq.addOperation(op1)
//opq.addOperation(op2)


let dic = ["a":1, "b":2]
print(Array(dic.keys.elements))
print(dic.keys.elements)




