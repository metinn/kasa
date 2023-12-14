//
//  ApiGetSetTests.swift
//  
//
//  Created by Metin Güler on 28.07.21.
//

import XCTest
@testable import kasa

class ApiGetSetTests: XCTestCase {
    override class func tearDown() {
        removeDatabase(name: "testdb")
    }
    
    func testKasaGetSet() async {
        let uuid = UUID().uuidString
        do {
            let kasa = try await Kasa(name: "testdb")
            let car = Car(id: uuid, brand: "Suzuki", kmt: 12111)
            try await kasa.save(car)
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }

        do {
            let kasa = try await Kasa(name: "testdb")
            let car = try await kasa.object(Car.self, forId: uuid)
            XCTAssertNotNil(car)
            XCTAssertEqual(car!.brand, "Suzuki")
            XCTAssertEqual(car!.kmt, 12111)
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
