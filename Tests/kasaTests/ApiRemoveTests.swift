//
//  ApiRemoveTests.swift
//  
//
//  Created by Metin Güler on 28.07.21.
//

import XCTest
@testable import kasa

class ApiRemoveTests: XCTestCase {
    func testRemove() {
        put100Car()
        
        do {
            let kasa = try Kasa(name: "testdb")
            
            try kasa.remove(Car.self, forUuid: "Cars-0042")
            
            let car = try kasa.object(Car.self, forUuid: "Cars-0042")
            XCTAssertNil(car)
            
            let existingCar = try kasa.object(Car.self, forUuid: "Cars-0024")
            XCTAssertNotNil(existingCar)
            
            let allCar = try kasa.objects(Car.self)
            XCTAssertEqual(allCar.count, 99)
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testRemoveAll() {
        put100Car()
        
        do {
            let kasa = try Kasa(name: "testdb")
            
            try kasa.removeAll(Car.self)
            
            let car = try kasa.object(Car.self, forUuid: "Cars-0042")
            XCTAssertNil(car)
            
            let allCar = try kasa.objects(Car.self)
            XCTAssertEqual(allCar.count, 0)
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
