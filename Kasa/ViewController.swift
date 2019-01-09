//
//  ViewController.swift
//  Kasa
//
//  Created by Metin Guler on 8.07.2018.
//  Copyright © 2018 Metin Guler. All rights reserved.
//

import UIKit

struct Person: Codable {
    let name: String
    let age: Int
    let height: Double
}

class ViewController: UIViewController {
    override func viewDidLoad() {

        guard let kasa = try? Kasa(name: "test") else { return }
        kasa.update { tran in
            try tran.save(Person(name: "Metin", age: 28, height: 172.3), withKey: "me")
            let person = try tran.fetch(Person.self, withKey: "me")

            print("Kasa:", "me: ", person?.name ?? "nil")
            throw NSError(domain: "test", code: 101, userInfo: nil)
        }.onError { err in
            print("Kasa:", "Some error occured:", err.localizedDescription)

            kasa.view { tran in
                let person = try tran.fetch(Person.self, withKey: "me")
                print("Kasa:", person ?? "nil")
            }
        }
    }
}
