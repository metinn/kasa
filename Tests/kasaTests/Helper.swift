//
//  File.swift
//  
//
//  Created by Metin Güler on 28.07.21.
//

import XCTest
@testable import kasa

struct Car: Storable {
    var id: String
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
            print("Kasa:", String(format: "Brand%i", index), String(format: "Cars-%.4i", index))
        }
    } catch let err {
        print(err.localizedDescription)
        XCTAssert(false)
    }
}
