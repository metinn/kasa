//
//  ApiRemoveTests.swift
//  
//
//  Created by Metin Güler on 28.07.21.
//

import XCTest
@testable import kasa

class ApiRemoveTests: XCTestCase {
    func testRemove() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            try await kasa.remove(Car.self, forUuid: "Cars-0042")
            
            let car = try await kasa.object(Car.self, forUuid: "Cars-0042")
            XCTAssertNil(car)
            
            let existingCar = try await kasa.object(Car.self, forUuid: "Cars-0024")
            XCTAssertNotNil(existingCar)
            
            let allCar = try await kasa.objects(Car.self)
            XCTAssertEqual(allCar.count, 99)
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testRemoveAll() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            try await kasa.removeAll(Car.self)
            
            let car = try await kasa.object(Car.self, forUuid: "Cars-0042")
            XCTAssertNil(car)
            
            let allCar = try await kasa.objects(Car.self)
            XCTAssertEqual(allCar.count, 0)
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
