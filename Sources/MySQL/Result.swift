//
//  Result.swift
//  MySQL
//
//  Created by ito on 12/10/15.
//  Copyright © 2015 Yusuke Ito. All rights reserved.
//

import Foundation

internal protocol SQLRawStringDecodable {
    static func fromSQLValue(string: String) throws -> Self
}

internal struct QueryRowResult {
    
    private let fields: [Connection.Field]
    private let fieldValues: [Connection.FieldValue]
    internal let columnMap: [String: Connection.FieldValue] // the key is field name
    init(fields: [Connection.Field], fieldValues: [Connection.FieldValue]) {
        self.fields = fields
        self.fieldValues = fieldValues
        var map:[String: Connection.FieldValue] = [:]
        for i in 0..<fieldValues.count {
            map[fields[i].name] = fieldValues[i]
        }
        self.columnMap = map
    }
    
    func isNull(forField field: String) -> Bool {
        guard let fieldValue = columnMap[field] else {
            return false
        }
        switch fieldValue {
        case .null:
            return true
        case .binary, .date:
            return false
        }
    }
    
    private func castOrFail<T: SQLRawStringDecodable>(_ obj: String, field: String) throws -> T {
        //print("casting val \(obj) to \(T.self)")
        do {
            return try T.fromSQLValue(string: obj)
        } catch {
            throw MySQLQueryError.SQLRawStringDecodeError(error: error, actualValue: obj, expectedType: "\(T.self)", forField: field)
        }
    }
    
    private func getValue<T: SQLRawStringDecodable>(fieldValue: Connection.FieldValue, field: String) throws -> T {
        switch fieldValue {
        case .null:
            throw MySQLQueryError.resultCastError(actualValue: "NULL", expectedType: "\(T.self)", forField: field)
        case .date(let string, let timezone):
            if T.self == Date.self {
                return try Date(sqlDate: string, timeZone: timezone) as! T
            } else if T.self == DateComponents.self {
                return try DateComponents.fromSQLValue(string: string) as! T
            }
            throw MySQLQueryError.resultCastError(actualValue: "\(string)", expectedType: "\(T.self)", forField: field)
        case .binary(let data):
            //print("T is \(T.self)")
            if let bin = data as? T {
                return bin
            }
            return try castOrFail(fieldValue.string(), field: field)
        }
    }
    
    func getValue<T: SQLRawStringDecodable>(forField field: String) throws -> T {
        guard let fieldValue = columnMap[field] else {
            throw MySQLQueryError.missingField(field)
        }
        return try getValue(fieldValue: fieldValue, field: field)
    }    
}

internal struct QueryRowResultDecoder : Decoder {
    let codingPath = [CodingKey]()
    let userInfo = [CodingUserInfoKey : Any]()
    let row: QueryRowResult
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(RowKeyedDecodingContainer<Key>(decoder: self))
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw MySQLQueryError.resultDecodeErrorMessage(message: "Decoder unkeyedContainer not implemented")
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw MySQLQueryError.resultDecodeErrorMessage(message: "Decoder singleValueContainer not implemented")
    }
}

fileprivate struct SQLStringDecoder: Decoder {
    let codingPath =  [CodingKey]()
    let userInfo = [CodingUserInfoKey : Any]()
    let sqlString: String
    
    struct SingleValue: SingleValueDecodingContainer {
        let codingPath =  [CodingKey]()
        let sqlString: String
        func decodeNil() -> Bool {
            fatalError()
        }
        
        func decode(_ type: Bool.Type) throws -> Bool {
            fatalError()
        }
        
        func decode(_ type: Int.Type) throws -> Int {
            return try Int.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: Int8.Type) throws -> Int8 {
            return try Int8.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: Int16.Type) throws -> Int16 {
            return try Int16.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: Int32.Type) throws -> Int32 {
            return try Int32.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: Int64.Type) throws -> Int64 {
            return try Int64.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: UInt.Type) throws -> UInt {
            return try UInt.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: UInt8.Type) throws -> UInt8 {
            return try UInt8.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: UInt16.Type) throws -> UInt16 {
            return try UInt16.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: UInt32.Type) throws -> UInt32 {
            return try UInt32.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: UInt64.Type) throws -> UInt64 {
            return try UInt64.fromSQLValue(string: sqlString)
        }
        
        func decode(_ type: Float.Type) throws -> Float {
            fatalError()
        }
        
        func decode(_ type: Double.Type) throws -> Double {
            fatalError()
        }
        
        func decode(_ type: String.Type) throws -> String {
            return sqlString
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            fatalError()
        }
        
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        throw MySQLQueryError.resultDecodeErrorMessage(message: "RawTypeDecoder container(keyedBy:) not implemented, you could implement `QueryRowResultCustomData` type:\(type)")
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw MySQLQueryError.resultDecodeErrorMessage(message: "RawTypeDecoder unkeyedContainer not implemented")
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValue(sqlString: sqlString)
    }
 }

fileprivate struct RowKeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol {
    typealias Key = K
    
    let decoder : QueryRowResultDecoder
    
    let allKeys = [Key]()
    
    let codingPath = [CodingKey]()
    
    func decodeNil(forKey key: K) throws -> Bool {
        return false
    }
    
    func contains(_ key: K) -> Bool {
        return decoder.row.columnMap[key.stringValue] != nil && !decoder.row.isNull(forField: key.stringValue)
    }
    
    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        return try decoder.row.getValue(forField: key.stringValue)
    }
    
    func decode(_ type: String.Type, forKey key: K) throws -> String {
        return try decoder.row.getValue(forField: key.stringValue) as String
    }
    
    func decode<T>(_ t: T.Type, forKey key: K) throws -> T where T : Decodable {
        if t == Data.self {
            return try decoder.row.getValue(forField: key.stringValue) as Data as! T
        } else if t == Date.self {
            return try decoder.row.getValue(forField: key.stringValue) as Date as! T
        } else if t == DateComponents.self {
            return try decoder.row.getValue(forField: key.stringValue) as DateComponents as! T
        } else if t == URL.self {
            let urlString = try decoder.row.getValue(forField: key.stringValue) as String
            guard let url = URL(string: urlString) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                        debugDescription: "Invalid URL string."))
            }
            return url as! T
        } else if t == Decimal.self {
            return try decoder.row.getValue(forField: key.stringValue) as Decimal as! T
        } else if let customType = t as? QueryRowResultCustomData.Type {
            let data = try decoder.row.getValue(forField: key.stringValue) as Data
            return try customType.decode(fromRowData: data) as! T
        }
        guard let columnValue = decoder.row.columnMap[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: [key], debugDescription: ""))
        }
        if let data = (try columnValue.string()).data(using: .utf8){
            let model = try JSONDecoder().decode(T.self, from: data)
            return model
        }
        let d = SQLStringDecoder(sqlString: try columnValue.string())
        return try T(from: d)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
        throw MySQLQueryError.resultDecodeErrorMessage(message: "KeyedDecodingContainer nestedContainer not implemented")
    }
    
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        throw MySQLQueryError.resultDecodeErrorMessage(message: "KeyedDecodingContainer nestedContainer not implemented")
    }
    
    func superDecoder() throws -> Decoder {
        throw MySQLQueryError.resultDecodeErrorMessage(message: "KeyedDecodingContainer superDecoder not implemented")
    }
    
    func superDecoder(forKey key: K) throws -> Decoder {
        throw MySQLQueryError.resultDecodeErrorMessage(message: "KeyedDecodingContainer superDecoder(forKey) not implemented")
    }
}
