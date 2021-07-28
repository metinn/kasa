//
//  KasaTests.swift
//  KasaTests
//
//  Created by Metin Guler on 8.07.2018.
//  Copyright © 2018 Metin Guler. All rights reserved.
//

import XCTest
@testable import kasa

class KasaTests: XCTestCase {

    func testOpeningDatabaseTwice() {
        do {
            let dbName = "testdb"

            var kasa1 = try Kasa(name: dbName)
            try kasa1.set(Car(brand: "Brand1", kmt: 12_111), forKey: "key1")

            kasa1 = try Kasa(name: dbName)
            let car = try kasa1.get(Car.self, forKey: "key1")
            XCTAssert( (car?.brand ?? "") == "Brand1" )

        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }

    func testConcurrent() {
        DispatchQueue.concurrentPerform(iterations: 100) { iteration in
            do {
                let kasa = try Kasa(name: "testdb")
                try kasa.set(Car(brand: "Tofas\(iteration)", kmt: 5432.0), forKey: "tofas\(iteration)")
            } catch let err {
                print("testConcurrent:", err.localizedDescription)
                XCTAssert(false)
            }
        }

        do {
            let kasa = try Kasa(name: "testdb")
            for iteration in 0...99 {
                let car = try kasa.get(Car.self, forKey: "tofas\(iteration)")
                XCTAssert(car != nil)
            }
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
