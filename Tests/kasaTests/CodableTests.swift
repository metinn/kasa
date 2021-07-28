//
//  CodableTests.swift
//  KasaTests
//
//  Created by Metin Guler on 8.07.2018.
//  Copyright © 2018 Metin Guler. All rights reserved.
//

import XCTest
@testable import kasa

class CodableTests: XCTestCase {
    
    func testCodableInsertSync() {
        let key = "testCodableInsertSync"
        let value = "codableValue"

        do {
            let kasa = try Kasa(name: "testdb")
            try kasa.set(Car(brand: value, kmt: 5432.0), forKey: key)
            let fetchedCar = try kasa.get(Car.self, forKey: key)

            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value)
        } catch let err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }

    func testCodableUpdateSync() {
        let key = "testCodableUpdateSync"
        let value1 = "codableValue1"
        let value2 = "codableValue2"

        do {
            let kasa = try Kasa(name: "testdb")
            try kasa.set(Car(brand: value1, kmt: 5432.0), forKey: key)
            try kasa.set(Car(brand: value2, kmt: 121.0), forKey: key)
            let fetchedCar = try kasa.get(Car.self, forKey: key)

            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value2)
        } catch let err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }

    func testCodableDeleteSync() {
        let key = "testCodableDeleteSync"
        let value = "codableValue"

        do {
            let kasa = try Kasa(name: "testdb")
            try kasa.set(Car(brand: value, kmt: 5432.0), forKey: key)

            let fetchedCar = try kasa.get(Car.self, forKey: key)
            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value)

            try kasa.remove(Car.self, forKey: key)
            XCTAssert(try kasa.get(Car.self, forKey: key) == nil)
        } catch let err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }
}
