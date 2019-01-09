//
//  KasaTests.swift
//  KasaTests
//
//  Created by Metin Guler on 8.07.2018.
//  Copyright © 2018 Metin Guler. All rights reserved.
//

import XCTest
@testable import Kasa

class KasaTests: XCTestCase {
    var kasa: Kasa?

    override func setUp() {
        do {
            self.kasa = try Kasa(name: "testdb")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }

    override func tearDown() {
        self.kasa = nil
    }

    func testOpeningDatabaseTwice() {
        do {
            let dbName = "testdb"

            var kasa1 = try Kasa(name: dbName)
            _ = kasa1.updateSync { tran in
                try tran.save(Car(brand: "Brand1", kmt: 12_111), withKey: "key1")
            }

            kasa1 = try Kasa(name: dbName)
            _ = kasa1.viewSync { tran in
                let car = try tran.fetch(Car.self, withKey: "key1")
                XCTAssert( (car?.brand ?? "") == "Brand1" )
            }

        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }

    func testConcurrent() {
        DispatchQueue.concurrentPerform(iterations: 100) { iteration in
            let err = kasa!.updateSync { tran in
                try tran.save(Car(brand: "Tofas\(iteration)", kmt: 5432.0), withKey: "tofas\(iteration)")
            }

            if let err = err {
                print(err.localizedDescription)
                XCTAssert(false)
            }
        }

        let err = kasa!.viewSync { tran in
            for iteration in 0...99 {
                let car = try tran.fetch(Car.self, withKey: "tofas\(iteration)")
                XCTAssert(car != nil)
            }
        }

        if let err = err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }

    func testKasaGetSet() {
        var err = kasa!.updateSync { tran in
            let car = Car(brand: "Suzuki", kmt: 12111)
            try tran.save(car, withKey: "alto")
        }
        if let err = err {
            print(err.localizedDescription)
            XCTAssert(false)
        }

        err = kasa!.viewSync { tran in
            let car = try tran.fetch(Car.self, withKey: "alto")
            XCTAssert(car?.brand != nil)
            XCTAssert(car!.brand == "Suzuki")
        }
        if let err = err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }

    func testGetMany() {
        var err = kasa!.updateSync { tran in
            for index in 1...100 {
                try tran.save(
                    Car(brand: String(format: "Brand%i", index), kmt: 100.0 * Double(index)),
                    withKey: String(format: "Cars-%.4i", index)
                )
                print("Kasa:", String(format: "Brand%i", index), String(format: "Cars-%.4i", index))
            }
        }
        if let err = err {
            print(err.localizedDescription)
            XCTAssert(false)
        }

        err = kasa!.viewSync { tran in
            let car = try tran.fetch(Car.self, withKey: "Cars-0085")
            XCTAssert(car?.brand == "Brand85")

            let cars = try tran.fetchMany(Car.self, startKey: "Cars-0010", toKey: "Cars-0030", limit: 13)
            XCTAssert(cars.count == 13)
            XCTAssert(cars.first!.brand == "Brand10")
            XCTAssert(cars.last!.brand == "Brand22")
        }

        if let err = err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
