//
//  JsonTests.swift
//  
//
//  Created by Metin Güler on 04.08.21.
//

import XCTest
@testable import kasa
import SQLite3

class JsonTests: XCTestCase {
    func testFilter() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "$brand = ?", params: ["Brand14"])
            XCTAssertEqual(cars.count, 1)
            XCTAssertEqual(cars.first!.brand, "Brand14")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testFilterLike() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "$brand like ?", params: ["Brand1%"])
            XCTAssertEqual(cars.count, 12)
            XCTAssertEqual(cars.first!.brand, "Brand1")
            XCTAssertEqual(cars.last!.brand, "Brand100")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testFilterOrderDesc() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "$brand like ?", params: ["Brand1%"], orderBy: "$brand desc")
            XCTAssertEqual(cars.count, 12)
            XCTAssertEqual(cars.first!.brand, "Brand19")
            XCTAssertEqual(cars.last!.brand, "Brand1")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
