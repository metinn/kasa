//
//  Kasa.swift
//  Kasa
//
//  Created by Metin Guler on 8.07.2018.
//  Copyright © 2018 Metin Guler. All rights reserved.
//

import Foundation
import SQLite3

class Kasa {
    var db: OpaquePointer

    fileprivate var errorMessage: String {
        return Kasa.errorMessage(dbp: db)
    }

    let sqliteTransient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

    // MARK: - Init
    convenience init(name: String, queue: DispatchQueue? = nil) throws {
        try self.init(dbPath: Kasa.dbPath(name: name))
    }

    init(dbPath: String) throws {
        var dbp: OpaquePointer?
        let firstInit = !FileManager.default.fileExists(atPath: dbPath)
        if sqlite3_open_v2(dbPath, &dbp, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK || dbp != nil {
            db = dbp!
            
            // wait until previous work finished. Otherwise it will return 'database is locked' error
            sqlite3_busy_timeout(db, 1000)
            
            if firstInit {
                // enable wal mode
                try? self.execute(sql: "PRAGMA journal_mode = WAL")
                
                try? self.createKVTable()
            }
            return
        }

        var err: String?
        if let dbp = dbp {
            err = Kasa.errorMessage(dbp: dbp)
            sqlite3_close(dbp)
        }
        throw NSError(domain: err ?? "", code: -1, userInfo: nil)
    }

    deinit {
        sqlite3_close(db)
    }
}

// MARK: - SQL Init
extension Kasa {
    private func createKVTable() throws {
        do {
            let sql = """
                CREATE TABLE KV(
                  kkey TEXT PRIMARY KEY NOT NULL,
                  valueType TEXT,
                  value BLOB
                );
            """
            try self.execute(sql: sql)

            try self.createIndex()
        } catch let err {
            throw err
        }
    }

    private func createIndex() throws {
        try execute(sql: "CREATE UNIQUE INDEX kkeyIndex ON KV(kkey, valueType);")
    }
}

// MARK: - Public API
extension Kasa {
    func set<T>(_ object: T, forKey key: String) throws where T: Codable {
        let typeName = "\(T.self)"
        let value = try JSONEncoder().encode(object)
        let sql = "INSERT or REPLACE INTO KV (kkey, valueType, value) VALUES (?, ?, ?);"
        let statement = try prepareStatement(sql: sql, params: [key, typeName, value])
        try execute(statement: statement)
    }

    func get<T>(_ type: T.Type, forKey key: String) throws -> T? where T: Codable {
        let typeName = "\(type)"
        let sql = "Select value From KV Where valueType = ? and kkey = ?;"
        let statement = try prepareStatement(sql: sql, params: [typeName, key])
        let dataArray = try query(statement: statement)
        
        guard let data = dataArray.first else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func getMany<T>(_ type: T.Type, startKey: String? = nil, endKey: String? = nil, limit: Int32? = nil) throws -> [T] where T: Codable {
        let typeName = "\(type)"

        var sql = "Select value From KV Where valueType = ?"
        var params: [Any] = [typeName]

        if let startKey = startKey {
            sql += " and kkey >= ?"
            params.append(startKey)
        }
        
        if let endKey = endKey {
            sql += " and kkey < ?"
            params.append(endKey)
        }
        
        sql += " order by kkey"
        
        if let limit = limit {
            sql += " limit ?"
            params.append(limit)
        }
        
        let statement = try prepareStatement(sql: sql, params: params)
        let dataArray = try query(statement: statement)
        
        return try dataArray.map {
            try JSONDecoder().decode(type, from: $0)
        }
    }

    func remove<T>(_ type: T.Type, forKey key: String) throws where T: Codable {
        let typeName = "\(type)"
        let sql = "Delete From KV Where valueType = ? and kkey = ?;"
        let statement = try prepareStatement(sql: sql, params: [typeName, key])
        try execute(statement: statement)
    }
    
    func removeAll<T>(_ type: T.Type) throws where T: Codable {
        let typeName = "\(type)"
        let sql = "Delete From KV Where valueType = ?;"
        let statement = try prepareStatement(sql: sql, params: [typeName])
        try execute(statement: statement)
    }
}

// MARK: - Kasa Transaction
extension Kasa {
    func beginTransaction() throws {
        try execute(sql: "begin exclusive transaction;")
    }

    func commitTransaction() throws {
        try execute(sql: "commit transaction;")
    }

    func rollbackTransaction() throws {
        try execute(sql: "rollback transaction;")
    }
}

// MARK: - Util
extension Kasa {
    private func prepareStatement(sql: String, params: [Any]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: errorMessage, code: -1, userInfo: nil)
        }

        var index: Int32 = 1
        for param in params {
            if let stringParam = param as? String {
                if sqlite3_bind_text(statement, index, stringParam, -1, sqliteTransient) != SQLITE_OK {
                    throw NSError(domain: errorMessage, code: -1, userInfo: nil)
                }
            } else if let intParam = param as? Int32 {
                if sqlite3_bind_int(statement, index, intParam) != SQLITE_OK {
                    throw NSError(domain: errorMessage, code: -1, userInfo: nil)
                }
            } else if let dataParam = param as? Data {
                try dataParam.withUnsafeBytes { p in
                    if sqlite3_bind_blob(statement, index, p.baseAddress, Int32(p.count), sqliteTransient) != SQLITE_OK {
                        throw NSError(domain: errorMessage, code: -1, userInfo: nil)
                    }
                }
            } else {
                throw NSError(domain: "Unsupported parameter type: Support more type if prepareStatement func become public", code: -1, userInfo: nil)
            }
            
            index += 1
        }

        return statement
    }

    private func execute(sql: String) throws {
        guard sqlite3_exec(db, sql.cString(using: .utf8), nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: errorMessage, code: -1, userInfo: nil)
        }
    }

    private func execute(statement: OpaquePointer?) throws {
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw NSError(domain: errorMessage, code: -1, userInfo: nil)
        }
    }

    fileprivate func query(statement: OpaquePointer?) throws -> [Data] {
        defer { sqlite3_finalize(statement) }

        var dataArray = [Data]()
        while sqlite3_step(statement) == SQLITE_ROW {
            let data = try getData(statement: statement, index: 0)
            dataArray.append(data)
        }

        return dataArray
    }
    
    func getString(statement: OpaquePointer?, index: Int32) throws -> String {
        guard let cStr = sqlite3_column_text(statement, index) else {
            throw NSError(domain: errorMessage, code: -1, userInfo: nil)
        }
        return String(cString: cStr)
    }
    
    func getData(statement: OpaquePointer?, index: Int32) throws -> Data {
        guard let blob = sqlite3_column_blob(statement, index) else {
            throw NSError(domain: errorMessage, code: -1, userInfo: nil)
        }
        let bytes = sqlite3_column_bytes(statement, index)
        return Data(bytes: blob, count: Int(bytes))
    }
}

extension Kasa {
    static func errorMessage(dbp: OpaquePointer) -> String {
        if let errorPointer = sqlite3_errmsg(dbp) {
            let errorMessage = String(cString: errorPointer)
            return errorMessage
        } else {
            return "No error message provided from sqlite."
        }
    }

    static private func dbPath(name: String) -> String {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return "\(path)/\(name).sqlite"
    }
}

// Migration
extension Kasa {
    func runMigration<T>(_ type: T.Type, migration: ([String: Any]) -> [String: Any]) throws where T: Codable {
        let sql = "Select kkey, value From KV Where valueType = ?"
        let typeName = "\(type)"
        
        let statement = try prepareStatement(sql: sql, params: [typeName])
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            // get the object
            let kkey = try getString(statement: statement, index: 0)
            let data = try getData(statement: statement, index: 1)
            // make it json
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String : Any]
            
            // run migration
            let newJsonObject = migration(jsonObject)
            
            // serialize new object
            let newData = try JSONSerialization.data(withJSONObject: newJsonObject, options: .fragmentsAllowed)
            // update the data on sqlite
            let sql = "Update KV Set value = ? Where kkey = ?;"
            let updateStatement = try prepareStatement(sql: sql, params: [newData, kkey])
            try execute(statement: updateStatement)
        }
    }
}
