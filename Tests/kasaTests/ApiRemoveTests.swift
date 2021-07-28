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
            
            try kasa.remove(Car.self, forKey: "Cars-0042")
            
            let car = try kasa.get(Car.self, forKey: "Cars-0042")
            XCTAssertNil(car)
            
            let existingCar = try kasa.get(Car.self, forKey: "Cars-0024")
            XCTAssertNotNil(existingCar)
            
            let allCar = try kasa.getMany(Car.self)
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
            
            let car = try kasa.get(Car.self, forKey: "Cars-0042")
            XCTAssertNil(car)
            
            let allCar = try kasa.getMany(Car.self)
            XCTAssertEqual(allCar.count, 0)
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
