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
    override class func tearDown() {
        removeDatabase(name: "testdb")
    }

    func testOpeningDatabaseTwice() async {
        do {
            let dbName = "testdb"

            var kasa1 = try await Kasa(name: dbName)
            let uuid = UUID().uuidString
            try await kasa1.save(Car(id: uuid, brand: "Brand1", kmt: 12_111))

            kasa1 = try await Kasa(name: dbName)
            let car = try await kasa1.object(Car.self, forId: uuid)
            XCTAssertEqual((car?.brand ?? ""), "Brand1")

        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }

    func testConcurrent() async {
        await withTaskGroup(of: Bool.self) { group in
            for iteration in 0...99 {
                group.addTask {
                    do {
                        let kasa = try await Kasa(name: "testdb")
                        try await kasa.save(Car(id: "tofas\(iteration)", brand: "Tofas\(iteration)", kmt: 5432.0))
                        return true
                    } catch let err {
                        print("testConcurrent:", err.localizedDescription)
                        return false
                    }
                }
            }
            
            for await result in group {
                if result == false {
                    XCTFail("a test failed")
                }
            }
        }

        do {
            let kasa = try await Kasa(name: "testdb")
            for iteration in 0...99 {
                let car = try await kasa.object(Car.self, forId: "tofas\(iteration)")
                XCTAssert(car != nil)
            }
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testConcurrentSingleInstance() async {
        let kasa = try! await Kasa(name: "testdb")
        
        await withTaskGroup(of: Bool.self) { group in
            for iteration in 0...99 {
                group.addTask {
                    do {
                        try await kasa.save(Car(id: "tofas\(iteration)", brand: "Tofas\(iteration)", kmt: 5432.0))
                        return true
                    } catch let err {
                        print("testConcurrent:", err.localizedDescription)
                        return false
                    }
                }
            }
            
            for await result in group {
                if result == false {
                    XCTFail("a test failed")
                }
            }
        }

        do {
            let kasa = try await Kasa(name: "testdb")
            for iteration in 0...99 {
                let car = try await kasa.object(Car.self, forId: "tofas\(iteration)")
                XCTAssert(car != nil)
            }
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
