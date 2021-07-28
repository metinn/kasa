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
    fileprivate var dbPointer: OpaquePointer

    fileprivate var errorMessage: String {
        return Kasa.errorMessage(dbp: dbPointer)
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
            dbPointer = dbp!
            
            // wait until previous work finished. Otherwise it will return 'database is locked' error
            sqlite3_busy_timeout(dbPointer, 1000)
            
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
        throw KasaError.general(message: err ?? "")
    }

    deinit {
        sqlite3_close(dbPointer)
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
                  value TEXT
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
        let statement = try prepareStatement(sql: sql, params: [key, typeName, value.base64EncodedString()])
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
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
            throw KasaError.general(message: errorMessage)
        }

        var index: Int32 = 1
        for param in params {
            if let stringParam = param as? String {
                if sqlite3_bind_text(statement, index, stringParam, -1, sqliteTransient) != SQLITE_OK {
                    throw KasaError.general(message: errorMessage)
                }
            } else if let intParam = param as? Int32 {
                if sqlite3_bind_int(statement, index, intParam) != SQLITE_OK {
                    throw KasaError.general(message: errorMessage)
                }
            } else {
                throw KasaError.general(message: "Unsupported parameter type: Support more type if prepareStatement func become public")
            }
            
            index += 1
        }

        return statement
    }

    private func execute(sql: String) throws {
        guard sqlite3_exec(dbPointer, sql.cString(using: .utf8), nil, nil, nil) == SQLITE_OK else {
            throw KasaError.general(message: errorMessage)
        }
    }

    private func execute(statement: OpaquePointer?) throws {
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw KasaError.general(message: errorMessage)
        }
    }

    fileprivate func query(statement: OpaquePointer?) throws -> [Data] {
        defer { sqlite3_finalize(statement) }

        var dataArray = [Data]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let cStr = sqlite3_column_text(statement, 0) else {
                throw KasaError.general(message: errorMessage)
            }
            guard let data = Data.init(base64Encoded: String(cString: cStr)) else {
                throw KasaError.general(message: errorMessage)
            }
            dataArray.append(data)
        }

        return dataArray
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

// MARK: - Kasa Error
enum KasaError: Error {
    case general(message: String)
}

extension KasaError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .general(let message):
            return message
        }
    }
}
