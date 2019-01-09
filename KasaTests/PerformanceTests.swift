//
//  PerformanceTests.swift
//  KasaTests
//
//  Created by Metin Guler on 8.07.2018.
//  Copyright © 2018 Metin Guler. All rights reserved.
//

import XCTest
@testable import Kasa

class PerformanceTests: XCTestCase {
//    let transactionCount = 1000
//
//    func testWrite() {
//        var carList: [Car] = []
//        for i in 1...transactionCount {
//            carList.append(Car(brand: "Brand-\(i)", km: Double(1000 * i)))
//        }
//
//        let kasa = try! Kasa(name: "kasa")
//        self.measure {
//            _ = kasa.updateSync { tx in
//                try carList.forEach({ item in
//                    try tx.save(item, withKey: item.brand)
//                })
//            }
//        }
//    }
//
//    func testRead() {
//        let kasa = try! Kasa(name: "kasa")
//
//        self.measure {
//            _ = kasa.viewSync { tx in
//                for i in 1...self.transactionCount {
//                    _ = try tx.fetch(Car.self, withKey: "Brand-\(i)")
//                }
//            }
//        }
//    }
}
