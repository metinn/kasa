//
//  ApiGetManyTests.swift
//  
//
//  Created by Metin Güler on 28.07.21.
//

import XCTest
@testable import kasa

class ApiGetManyTests: XCTestCase {
    override class func tearDown() {
        removeDatabase(name: "testdb")
    }

    func testGetManyCheckGettingAll() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let allCars = try await kasa.objects(Car.self)
            XCTAssertEqual(allCars.count, 100)
            XCTAssertEqual(allCars.first!.brand, "Brand1")
            XCTAssertEqual(allCars.last!.brand, "Brand100")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testGetManyCheckStartKey() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "uuid >= ?", params: ["Cars-0017"])
            XCTAssertEqual(cars.count, 84)
            XCTAssertEqual(cars.first!.brand, "Brand17")
            XCTAssertEqual(cars.last!.brand, "Brand100")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testGetManyCheckEndKey() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "uuid < ?", params: ["Cars-0042"])
            XCTAssertEqual(cars.count, 41)
            XCTAssertEqual(cars.first!.brand, "Brand1")
            XCTAssertEqual(cars.last!.brand, "Brand41")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testGetManyCheckStartAndEndKey() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "uuid between ? and ?", params: ["Cars-0030", "Cars-0078"])
            XCTAssertEqual(cars.count, 49)
            XCTAssertEqual(cars.first!.brand, "Brand30")
            XCTAssertEqual(cars.last!.brand, "Brand78")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testGetManyCheckLimit() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "1=1", limit: 8)
            XCTAssertEqual(cars.count, 8)
            XCTAssertEqual(cars.first!.brand, "Brand1")
            XCTAssertEqual(cars.last!.brand, "Brand8")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testGetManyCheckLimitWithStartKey() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "uuid >= ?", params: ["Cars-0054"], limit: 7)
            XCTAssertEqual(cars.count, 7)
            XCTAssertEqual(cars.first!.brand, "Brand54")
            XCTAssertEqual(cars.last!.brand, "Brand60")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func testGetManyCheckLimitWithEndKey() async {
        await put100Car()
        
        do {
            let kasa = try await Kasa(name: "testdb")
            
            let cars = try await kasa.objects(Car.self, filter: "uuid < ?", params: ["Cars-0014"], limit: 20)
            XCTAssertEqual(cars.count, 13)
            XCTAssertEqual(cars.first!.brand, "Brand1")
            XCTAssertEqual(cars.last!.brand, "Brand13")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
