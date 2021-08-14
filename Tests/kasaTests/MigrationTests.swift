//
//  MigrationTests.swift
//  
//
//  Created by Metin Güler on 01.08.21.
//

import XCTest
@testable import kasa
import SQLite3

class MigrationTests: XCTestCase {
    struct Post: KasaStorable {
        let uuid: String
        let text: String
        let likes: Int?
        
        var primaryKey: String { return uuid }
    }
    
    func testMigration() {
        do {
            let kasa = try Kasa(name: "testdb")
            let uuid = UUID().uuidString
            try kasa.save(Post(uuid: uuid, text: "Hello There", likes: nil))

            try kasa.runMigration(Post.self) { json in
                var newJson = json
                newJson["likes"] = 1
                return newJson
            }
            
            let post = try kasa.object(Post.self, forUuid: uuid)
            XCTAssertNotNil(post, "post should not be nil")
            XCTAssertNotNil(post?.likes, "likes should not be nil")
            XCTAssertEqual(post!.likes, 1, "likes should not be equal to 1 which set with migration")
        } catch let err {
            print(err.localizedDescription)
            XCTAssert(false)
        }
    }
}
