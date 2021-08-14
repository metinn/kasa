//
//  Kasa.swift
//  Kasa
//
//  Created by Metin Guler on 8.07.2018.
//  Copyright © 2018 Metin Guler. All rights reserved.
//

import Foundation
import SQLite3

protocol KasaStorable: Codable {
    var primaryKey: String { get }
}

class Kasa {
    var db: OpaquePointer
    let sqliteTransient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

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
    private func createTableIfNeeded(name: String) throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS \(name)(
              uuid TEXT PRIMARY KEY NOT NULL,
              value BLOB
            );
        """
        try self.execute(sql: sql)
        try self.createIndex(indexName: "\(name)Index", tableName: name, expression: "uuid")
    }

    func createIndex(indexName: String, tableName: String, expression: String) throws {
        let exp = replaceJsonValuesWithFunction(expression)
        try execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS \(indexName) ON \(tableName)(\(exp));")
    }
}

// MARK: - Public API
extension Kasa {
    func save<T>(_ object: T) throws where T: KasaStorable {
        let typeName = "\(T.self)"
        do {
            let value = try JSONEncoder().encode(object)
            let sql = "INSERT or REPLACE INTO \(typeName) (uuid, value) VALUES (?, ?);"
            let statement = try prepareStatement(sql: sql, params: [object.primaryKey, value])
            try execute(statement: statement)
        } catch let err {
            guard err.localizedDescription.contains("no such table") else { throw err }
            try createTableIfNeeded(name: typeName)
            return try save(object)
        }
    }

    func object<T>(_ type: T.Type, forUuid uuid: String) throws -> T? where T: Codable {
        let typeName = "\(type)"
        let sql = "Select value From \(typeName) Where uuid = ?;"
        let statement = try prepareStatement(sql: sql, params: [uuid])
        let dataArray = try query(statement: statement)
        
        guard let data = dataArray.first else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
    
    func objects<T>(_ type: T.Type, filter: String? = nil, params: [Any] = [], orderBy: String? = nil, limit: Int32? = nil) throws -> [T] where T: Codable {
        let typeName = "\(type)"
        var sql = "Select value From \(typeName)"
        
        if let filter = filter {
            sql += " Where " + replaceJsonValuesWithFunction(filter)
        }
        
        if let orderby = orderBy {
            sql += " Order by " + replaceJsonValuesWithFunction(orderby)
        }
        
        if let limit = limit {
            sql += " Limit \(limit)"
        }
        
        let statement = try prepareStatement(sql: sql, params: params)
        let dataArray = try query(statement: statement)
        
        return try dataArray.map {
            try JSONDecoder().decode(type, from: $0)
        }
    }

    func remove<T>(_ type: T.Type, forUuid uuid: String) throws where T: Codable {
        let typeName = "\(type)"
        let sql = "Delete From \(typeName) Where uuid = ?;"
        let statement = try prepareStatement(sql: sql, params: [uuid])
        try execute(statement: statement)
    }
    
    func removeAll<T>(_ type: T.Type) throws where T: Codable {
        let typeName = "\(type)"
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

    private func query(statement: OpaquePointer?) throws -> [Data] {
        defer { sqlite3_finalize(statement) }

        var dataArray = [Data]()
        while sqlite3_step(statement) == SQLITE_ROW {
            let data = try getData(statement: statement, index: 0)
            dataArray.append(data)
        }

        return dataArray
    }
    
    private func getString(statement: OpaquePointer?, index: Int32) throws -> String {
        guard let cStr = sqlite3_column_text(statement, index) else {
            throw getLastError()
        }
        return String(cString: cStr)
    }
    
    private func getData(statement: OpaquePointer?, index: Int32) throws -> Data {
        guard let blob = sqlite3_column_blob(statement, index) else {
            throw getLastError()
        }
        let bytes = sqlite3_column_bytes(statement, index)
        return Data(bytes: blob, count: Int(bytes))
    }
    
    private func replaceJsonValuesWithFunction(_ filter: String) -> String {
        return filter.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").reduce("") { whereSql, word  in
            if word.hasPrefix("$") {
                return "\(whereSql) json_extract(value, '$.\(word.dropFirst())')"
            } else {
                return "\(whereSql) \(word)"
            }
        }
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
        let sql = "Select uuid, value From \(typeName)"
        
        let statement = try prepareStatement(sql: sql, params: [])
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            // get the object
            let uuid = try getString(statement: statement, index: 0)
            let data = try getData(statement: statement, index: 1)
            // make it json
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String : Any]
            
            // run migration
            let newJsonObject = migration(jsonObject)
            
            // serialize new object
            let newData = try JSONSerialization.data(withJSONObject: newJsonObject, options: .fragmentsAllowed)
            // update the data on sqlite
            let sql = "Update \(typeName) Set value = ? Where uuid = ?;"
            let updateStatement = try prepareStatement(sql: sql, params: [newData, uuid])
            try execute(statement: updateStatement)
        }
    }
}
