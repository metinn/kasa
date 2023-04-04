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
    
    func testCodableInsertSync() async {
        let key = "testCodableInsertSync"
        let value = "codableValue"

        do {
            let kasa = try await Kasa(name: "testdb")
            try await kasa.save(Car(id: key, brand: value, kmt: 5432.0))
            let fetchedCar = try await kasa.object(Car.self, forUuid: key)

            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value)
        } catch let err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }

    func testCodableUpdateSync() async {
        let key = "testCodableUpdateSync"
        let value1 = "codableValue1"
        let value2 = "codableValue2"

        do {
            let kasa = try await Kasa(name: "testdb")
            try await kasa.save(Car(id: key, brand: value1, kmt: 5432.0))
            try await kasa.save(Car(id: key, brand: value2, kmt: 121.0))
            let fetchedCar = try await kasa.object(Car.self, forUuid: key)

            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value2)
        } catch let err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }

    func testCodableDeleteSync() async {
        let key = "testCodableDeleteSync"
        let value = "codableValue"

        do {
            let kasa = try await Kasa(name: "testdb")
            try await kasa.save(Car(id: key, brand: value, kmt: 5432.0))

            let fetchedCar = try await kasa.object(Car.self, forUuid: key)
            XCTAssert(fetchedCar != nil)
            XCTAssert(fetchedCar!.brand == value)

            try await kasa.remove(Car.self, forUuid: key)
            let deletedObject = try await kasa.object(Car.self, forUuid: key)
            XCTAssert(deletedObject == nil)
        } catch let err {
            XCTAssert(false)
            print(err.localizedDescription)
        }
    }
}
