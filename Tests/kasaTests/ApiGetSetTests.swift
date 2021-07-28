//
//  ApiGetSetTests.swift
//  
//
//  Created by Metin Güler on 28.07.21.
//

import XCTest
@testable import kasa

class ApiGetSetTests: XCTestCase {
    func testKasaGetSet() {
        do {
            let kasa = try Kasa(name: "testdb")
            let car = Car(brand: "Suzuki", kmt: 12111)
            try kasa.set(car, forKey: "alto")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }

        do {
            let kasa = try Kasa(name: "testdb")
            let car = try kasa.get(Car.self, forKey: "alto")
            XCTAssertNotNil(car)
            XCTAssertEqual(car!.brand, "Suzuki")
            XCTAssertEqual(car!.kmt, 12111)
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
