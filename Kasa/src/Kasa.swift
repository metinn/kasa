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
    fileprivate var queue: DispatchQueue
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
        queue = DispatchQueue(label: "com.metinguler.kasa", attributes: .concurrent)

        var dbp: OpaquePointer?
        let isThereDatabase = FileManager.default.fileExists(atPath: dbPath)
        if sqlite3_open(dbPath, &dbp) == SQLITE_OK || dbp != nil {
            dbPointer = dbp!
            if isThereDatabase == false {
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

// MARK: - Concurency
extension Kasa {
    @discardableResult
    func view(work: @escaping (KasaTransactionView)throws->Void) -> KasaErrorChain {
        let chain = KasaErrorChain()
        queue.async {
            do { try work(KasaTransaction(kasa: self)) } catch let err { chain.errorBlock?(err) }
        }
        return chain
    }

    func viewSync(work: @escaping (KasaTransactionView)throws->Void) -> Error? {
        var error: Error?
        queue.sync {
            do { try work(KasaTransaction(kasa: self)) } catch let err { error = err }
        }
        return error
    }

    @discardableResult
    func update(work: @escaping (KasaTransaction)throws->Void) -> KasaErrorChain {
        let chain = KasaErrorChain()
        queue.async(flags: .barrier) {
            do {
                try self.beginTransaction()
                try work(KasaTransaction(kasa: self))
                try self.commitTransaction()
            } catch let err {
                var error = err
                // TODO: Explicit error for rollback fail
                do {
                    try self.rollbackTransaction()
                } catch let rollbackErr {
                    error = rollbackErr
                }
                chain.errorBlock?(error)
            }
        }
        return chain
    }

    func updateSync(work: @escaping (KasaTransaction)throws->Void) -> Error? {
        var error: Error?
        queue.sync(flags: .barrier) {
            do {
                try self.beginTransaction()
                try work(KasaTransaction(kasa: self))
                try self.commitTransaction()
            } catch let err {
                error = err
                // TODO: Explicit error for rollback fail
                do {
                    try self.rollbackTransaction()
                } catch let rollbackErr {
                    error = rollbackErr
                }
            }
        }
        return error
    }
}

class KasaErrorChain {
    var errorBlock: ((Error) -> Void)?

    func onError(errorBlock: @escaping (Error) -> Void) {
        self.errorBlock = errorBlock
    }
}

// MARK: - SQL Init
extension Kasa {
    private func createKVTable() throws {
        let err = updateSync { _ in
            let sql = """
                CREATE TABLE KV(
                  kkey TEXT PRIMARY KEY NOT NULL,
                  value TEXT
                );
            """
            let statement = try self.prepareStatement(sql: sql)
            defer {
                sqlite3_finalize(statement)
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw KasaError.general(message: self.errorMessage)
            }

            try self.createIndex()
        }

        if let err = err {
            throw err
        }
    }

    private func createIndex() throws {
        let sql = "CREATE UNIQUE INDEX kkeyIndex ON KV(kkey);"

        let statement = try prepareStatement(sql: sql)
        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw KasaError.general(message: errorMessage)
        }
    }
}

// MARK: - Internal Get / Set
extension Kasa {
    fileprivate func set(_ key: String, _ value: Data) throws {
        let sql = "INSERT or REPLACE INTO KV (kkey, value) VALUES (?, ?);"
        let statement = try prepareStatement(sql: sql, key, value.base64EncodedString())
        try execute(statement: statement)
    }

    fileprivate func get(_ key: String) throws -> Data? {
        let sql = "Select value From KV Where kkey = ?;"
        let statement = try prepareStatement(sql: sql, key)
        let dataArray = try query(statement: statement)
        return dataArray.first
    }

    fileprivate func getMany(_ startKey: String, toKey: String, limit: Int32) throws -> [Data] {
        let sql = "Select value From KV Where kkey between ? and ? order by kkey limit ?;"
        let statement = try prepareStatement(sql: sql, startKey, toKey, limit)
        let dataArray = try query(statement: statement)
        return dataArray
    }

    fileprivate func remove(_ key: String) throws {
        let sql = "Delete From KV Where kkey = ?;"
        let statement = try prepareStatement(sql: sql, key)
        try execute(statement: statement)
    }
}

// MARK: - Public Get / Set
protocol KasaTransactionView {
    func fetch<T: Codable>(_ type: T.Type, withKey: String) throws -> T?
    func fetchMany<T>(_ type: T.Type, startKey: String, toKey: String, limit: Int32) throws -> [T] where T: Codable
}

class KasaTransaction: KasaTransactionView {
    let kasa: Kasa
    init(kasa: Kasa) {
        self.kasa = kasa
    }

    func fetch<T>(_ type: T.Type, withKey: String) throws -> T? where T: Codable {
        guard let data = try kasa.get(withKey) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func fetchMany<T>(_ type: T.Type, startKey: String, toKey: String, limit: Int32) throws -> [T] where T: Codable {
        let dataArray = try kasa.getMany(startKey, toKey: toKey, limit: limit)
        return try dataArray.map { try JSONDecoder().decode(type, from: $0) }
    }

    func save<T>(_ object: T, withKey: String) throws where T: Codable {
        try kasa.set(withKey, try JSONEncoder().encode(object))
    }

    func remove(_ key: String) throws {
        try kasa.remove(key)
    }
}

// MARK: - Util
extension Kasa {
    private func prepareStatement(sql: String, _ params: Any...) throws -> OpaquePointer? {
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

// MARK: - Kasa Transaction
extension Kasa {
    private func beginTransaction() throws {
        try execute(sql: "begin exclusive transaction;")
    }

    private func commitTransaction() throws {
        try execute(sql: "commit transaction;")
    }

    private func rollbackTransaction() throws {
        try execute(sql: "rollback transaction;")
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

// MARK: - Result
enum Result<T> {
    case value(T)
    case error(Error)
}

extension Kasa {
    func value(forKey key: String, ofType type: T.Type) -> Result<T> {
        var r: T?
        var e: Error?
        self.view { trans in
            r = try trans.fetch(type, withKey: key)
        }.onError { err in
            e = err
        }
        if let result = r { return .value(result) }
        return .error(e ?? KasaError.general(message: "This operation couldn't be completed"))
    }
]
