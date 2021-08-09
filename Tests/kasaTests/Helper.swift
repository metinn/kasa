//
//  File.swift
//  
//
//  Created by Metin Güler on 28.07.21.
//

import XCTest
@testable import kasa

struct Car: KasaObject {
    var uuid: String
    var brand: String
    var kmt: Double
}

func put100Car() {
    do {
        let kasa = try Kasa(name: "testdb")
        try? kasa.removeAll(Car.self)
        
        for index in 1...100 {
            try kasa.save(Car(uuid: String(format: "Cars-%.4i", index),
                             brand: String(format: "Brand%i", index),
                             kmt: 100.0 * Double(index)))
            print("Kasa:", String(format: "Brand%i", index), String(format: "Cars-%.4i", index))
        }
    } catch let err {
        print(err.localizedDescription)
        XCTAssert(false)
    }
}
