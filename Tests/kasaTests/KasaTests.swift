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

    func testOpeningDatabaseTwice() async {
        do {
            let dbName = "testdb"

            var kasa1 = try await Kasa(name: dbName)
            let uuid = UUID().uuidString
            try await kasa1.save(Car(uuid: uuid, brand: "Brand1", kmt: 12_111))

            kasa1 = try await Kasa(name: dbName)
            let car = try await kasa1.object(Car.self, forUuid: uuid)
            XCTAssertEqual((car?.brand ?? ""), "Brand1")

        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }

    func testConcurrent() async {
        DispatchQueue.concurrentPerform(iterations: 100) { iteration in
            Task {
                do {
                    let kasa = try await Kasa(name: "testdb")
                    try await kasa.save(Car(uuid: "tofas\(iteration)", brand: "Tofas\(iteration)", kmt: 5432.0))
                } catch let err {
                    print("testConcurrent:", err.localizedDescription)
                    XCTAssert(false)
                }
            }
        }
        
        // TODO: run concurrentPerform block sync somehow
        await Task.sleep(1)

        do {
            let kasa = try await Kasa(name: "testdb")
            for iteration in 0...99 {
                let car = try await kasa.object(Car.self, forUuid: "tofas\(iteration)")
                XCTAssert(car != nil)
            }
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
