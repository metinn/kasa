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
    let sqliteTransient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
    
    static var tablesNames = [String]()
    static let queue = DispatchQueue(label: "com.metinguler.kasa")

    // MARK: - Init
    convenience init(name: String) throws {
        try self.init(dbPath: Kasa.dbPath(name: name))
    }

    init(dbPath: String) throws {
        var dbp: OpaquePointer?
        let firstInit = !FileManager.default.fileExists(atPath: dbPath)
        let openResult = sqlite3_open_v2(dbPath, &dbp, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX, nil)
        if openResult == SQLITE_OK || dbp != nil {
            db = dbp!
            
            // wait until previous work finished. Otherwise it will return 'database is locked' error
            sqlite3_busy_timeout(db, 1000)
            
            if Kasa.tablesNames.isEmpty {
                Kasa.tablesNames = try getTables()
            }
            
            if firstInit {
                // enable wal mode
                try? self.execute(sql: "PRAGMA journal_mode = WAL")
            }
        } else {
            throw NSError(domain: "sqlite3_open_v2 failed with code: \(openResult)", code: -1, userInfo: nil)
        }
    }

    deinit {
        sqlite3_close(db)
    }
}

// MARK: - SQL Init
extension Kasa {
    private func getTables() throws -> [String] {
        let sql = """
            SELECT name FROM sqlite_master
            WHERE type ='table' AND name NOT LIKE 'sqlite_%';
        """
        
        let statement = try prepareStatement(sql: sql, params: [])
        defer { sqlite3_finalize(statement) }

        var tables = [String]()
        while sqlite3_step(statement) == SQLITE_ROW {
            let data = try getString(statement: statement, index: 0)
            tables.append(data)
        }
        return tables
    }
    
    private func createTableIfNeeded(name: String) throws {
        try Kasa.queue.sync {
            guard !Kasa.tablesNames.contains(name) else { return }
            
            let sql = """
                CREATE TABLE \(name)(
                  kkey TEXT PRIMARY KEY NOT NULL,
                  value BLOB
                );
            """
            try self.execute(sql: sql)
            try self.createPrimaryIndex(name: name)
            Kasa.tablesNames.append(name)
        }
    }

    private func createPrimaryIndex(name: String) throws {
        try execute(sql: "CREATE UNIQUE INDEX \(name)Index ON \(name)(kkey);")
    }
}

// MARK: - Public API
extension Kasa {
    func set<T>(_ object: T, forKey key: String) throws where T: Codable {
        let typeName = "\(T.self)"
        try createTableIfNeeded(name: typeName)
        let value = try JSONEncoder().encode(object)
        let sql = "INSERT or REPLACE INTO \(typeName) (kkey, value) VALUES (?, ?);"
        let statement = try prepareStatement(sql: sql, params: [key, value])
        try execute(statement: statement)
    }

    func get<T>(_ type: T.Type, forKey key: String) throws -> T? where T: Codable {
        let typeName = "\(type)"
        try createTableIfNeeded(name: typeName)
        let sql = "Select value From \(typeName) Where kkey = ?;"
        let statement = try prepareStatement(sql: sql, params: [key])
        let dataArray = try query(statement: statement)
        
        guard let data = dataArray.first else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func getMany<T>(_ type: T.Type, startKey: String? = nil, endKey: String? = nil, limit: Int32? = nil) throws -> [T] where T: Codable {
        let typeName = "\(type)"
        try createTableIfNeeded(name: typeName)

        var sql = "Select value From \(typeName) Where 1 = 1" // TODO: better way needed to build sql
        var params: [Any] = []

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
        try createTableIfNeeded(name: typeName)
        let sql = "Delete From \(typeName) Where kkey = ?;"
        let statement = try prepareStatement(sql: sql, params: [key])
        try execute(statement: statement)
    }
    
    func removeAll<T>(_ type: T.Type) throws where T: Codable {
        let typeName = "\(type)"
        try createTableIfNeeded(name: typeName)
        try execute(sql: "Delete From \(typeName)")
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
            throw getLastError()
        }

        var index: Int32 = 1
        for param in params {
            if let stringParam = param as? String {
                if sqlite3_bind_text(statement, index, stringParam, -1, sqliteTransient) != SQLITE_OK {
                    throw getLastError()
                }
            } else if let intParam = param as? Int32 {
                if sqlite3_bind_int(statement, index, intParam) != SQLITE_OK {
                    throw getLastError()
                }
            } else if let dataParam = param as? Data {
                try dataParam.withUnsafeBytes { p in
                    if sqlite3_bind_blob(statement, index, p.baseAddress, Int32(p.count), sqliteTransient) != SQLITE_OK {
                        throw getLastError()
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
            throw getLastError()
        }
    }

    private func execute(statement: OpaquePointer?) throws {
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw getLastError()
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
            throw getLastError()
        }
        return String(cString: cStr)
    }
    
    func getData(statement: OpaquePointer?, index: Int32) throws -> Data {
        guard let blob = sqlite3_column_blob(statement, index) else {
            throw getLastError()
        }
        let bytes = sqlite3_column_bytes(statement, index)
        return Data(bytes: blob, count: Int(bytes))
    }
}

extension Kasa {
    static private func dbPath(name: String) -> String {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return "\(path)/\(name).sqlite"
    }

    func getLastError() -> NSError {
        if let errorPointer = sqlite3_errmsg(db) {
            return NSError(domain: String(cString: errorPointer), code: -1, userInfo: nil)
        } else {
            return NSError(domain: "No error message provided from sqlite.", code: -1, userInfo: nil)
        }
    }
}

// Migration
extension Kasa {
    func runMigration<T>(_ type: T.Type, migration: ([String: Any]) -> [String: Any]) throws where T: Codable {
        let typeName = "\(type)"
        let sql = "Select kkey, value From \(typeName)"
        
        let statement = try prepareStatement(sql: sql, params: [])
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
            let sql = "Update \(typeName) Set value = ? Where kkey = ?;"
            let updateStatement = try prepareStatement(sql: sql, params: [newData, kkey])
            try execute(statement: updateStatement)
        }
    }
}
