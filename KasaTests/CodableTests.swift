//
//  CodableTests.swift
//  KasaTests
//
//  Created by Metin Guler on 8.07.2018.
//  Copyright © 2018 Metin Guler. All rights reserved.
//

import XCTest
@testable import Kasa

struct Car: Codable {
    var brand: String
    var kmt: Double
}

class CodableTests: XCTestCase {
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

    func testCodableInsertSync() {
        let key = "testCodableInsertSync"
        let value = "codableValue"

        let err = kasa?.updateSync { tran in
            try tran.save(Car(brand: value, kmt: 5432.0), withKey: key)
            let fetchedCar = try tran.fetch(Car.self, withKey: key)

            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value)
        }

        if let err = err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }

    func testCodableUpdateSync() {
        let key = "testCodableUpdateSync"
        let value1 = "codableValue1"
        let value2 = "codableValue2"

        let err = kasa!.updateSync { tran in
            try tran.save(Car(brand: value1, kmt: 5432.0), withKey: key)
            try tran.save(Car(brand: value2, kmt: 121.0), withKey: key)
            let fetchedCar = try tran.fetch(Car.self, withKey: key)

            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value2)
        }

        if let err = err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }

    func testCodableDeleteSync() {
        let key = "testCodableDeleteSync"
        let value = "codableValue"

        let err = kasa!.updateSync { tran in
            try tran.save(Car(brand: value, kmt: 5432.0), withKey: key)

            let fetchedCar = try tran.fetch(Car.self, withKey: key)
            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value)

            try tran.remove(key)
            XCTAssert(try tran.fetch(Car.self, withKey: key) == nil)
        }

        if let err = err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }
}
