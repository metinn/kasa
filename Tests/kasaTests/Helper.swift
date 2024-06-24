//
//  File.swift
//  
//
//  Created by Metin Güler on 28.07.21.
//

import XCTest
@testable import kasa

public struct Car: Storable {
    public var id: String
    var brand: String
    var kmt: Double
}

func put100Car() async {
    do {
        let kasa = try await Kasa(name: "testdb")
        try? await kasa.removeAll(Car.self)
        
        for index in 1...100 {
            try await kasa.save(Car(id: String(format: "Cars-%.4i", index),
                             brand: String(format: "Brand%i", index),
                             kmt: 100.0 * Double(index)))
        }
    } catch let err {
        print(err.localizedDescription)
        XCTAssert(false)
    }
}

func removeDatabase(name: String) {
    let dbPath = Kasa.dbPath(name: name)
    try? FileManager.default.removeItem(atPath: dbPath)
    try? FileManager.default.removeItem(atPath: dbPath+"-wal")
    try? FileManager.default.removeItem(atPath: dbPath+"-shm")
}
