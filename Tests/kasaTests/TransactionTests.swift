//
//  TransactionTests.swift
//  
//
//  Created by Metin Güler on 31.05.23.
//

import XCTest
@testable import kasa

class TransactionTests: XCTestCase {
    override class func tearDown() {
        removeDatabase(name: "testdb")
    }
    
    func testTransactionLocksTableDuringProcess() async {
        do {
            // Given
            let kasa = try await Kasa(name: "testdb")
            let car = Car(id: "1", brand: "vw", kmt: 100)
            try await kasa.save(car)
            
            // When
            try await kasa.beginTransaction()
            
            var returnedCar = try await kasa.object(Car.self, forId: "1")!
            returnedCar.kmt += 20

            // becuse transaction is still open, function below should fail with database is locked error
            Task { await increaseKmOfTheCar() }
            try await Task.sleep(for: .milliseconds(100))
            await increaseKmOfTheCar()

            try await kasa.save(returnedCar)
            try await kasa.commitTransaction()

            // Then
            let finalCar = try await kasa.object(Car.self, forId: "1")!
            XCTAssertEqual(finalCar.kmt, 120, "km should be 120(100 + 20), increaseKmOfTheCar func should fail because database is locked")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
    
    func increaseKmOfTheCar() async {
        do {
            let kasa = try await Kasa(name: "testdb")
            var car = try await kasa.object(Car.self, forId: "1")!
            car.kmt += 30
            try await kasa.save(car)
        } catch let err {
            print("increaseKmOfTheCar", err.localizedDescription)
        }
    }
    
    func testTransactionRollback() async {
        do {
            // Given
            let kasa = try await Kasa(name: "testdb")
            var car = Car(id: "1", brand: "vw", kmt: 200)
            try await kasa.save(car)

            // When
            try await kasa.beginTransaction()

            car.kmt = 500
            try await kasa.save(car)
            
            try await kasa.rollbackTransaction()
            
            // Then
            let rolledbackCar = try await kasa.object(Car.self, forId: "1")
            guard let rolledbackCar else {
                throw NSError(domain: "it is saved before transaction, can't be nil", code: 0)
            }
            XCTAssertEqual(rolledbackCar.kmt, 200, "Car kmt should be equal to initial value")
        } catch let err {
            XCTAssert(false, err.localizedDescription)
        }
    }
}
