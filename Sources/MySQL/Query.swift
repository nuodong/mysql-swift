//
//  Connection.swift
//  MySQL
//
//  Created by ito on 2015/10/24.
//  Copyright © 2015年 Yusuke Ito. All rights reserved.
//

import CMySQL
import SQLFormatter
import Foundation

public struct QueryStatus: CustomStringConvertible {
    public let affectedRows: UInt64?
    public let insertedID: UInt64
    
    init(mysql: UnsafeMutablePointer<MYSQL>) {
        self.insertedID = mysql_insert_id(mysql)
        let arows = mysql_affected_rows(mysql)
        if arows == (~0) {
            self.affectedRows = nil // error or select statement
        } else {
            self.affectedRows = arows
        }
    }
    
    public var description: String {
        return "insertedID:\(insertedID), affectedRows:" + (affectedRows != nil ? ("\(affectedRows!)") : "nil")
    }
}

internal extension String {
    func subString(max: Int) -> String {
        guard let r = index(startIndex, offsetBy: max, limitedBy: endIndex) else {
            return self
        }
        return String(self[startIndex..<r])
    }
}

extension Connection {
    
    internal struct NullValue {
        static let null = NullValue()
    }
    
    internal struct EmptyRowResult: Decodable {
        static func decodeRow(r: QueryRowResult) throws -> EmptyRowResult {
            return EmptyRowResult()
        }
    }
    
    internal struct Field {
        let name: String
        let type: enum_field_types
        init?(f: MYSQL_FIELD) {
            if f.name == nil {
                return nil
            }
            guard let fs = String(validatingUTF8: f.name) else {
                return nil
            }
            self.name = fs
            self.type = f.type
        }
        var isDate: Bool {
            return type == MYSQL_TYPE_DATE ||
                type == MYSQL_TYPE_DATETIME ||
                type == MYSQL_TYPE_TIME ||
                type == MYSQL_TYPE_TIMESTAMP
        }
        
    }
    
    internal enum FieldValue {
        case null
        case binary(Data)
        case date(dateString: String, timezone: TimeZone)
        
        static func makeBinary(ptr: UnsafeMutablePointer<Int8>, length: UInt) -> FieldValue {
            let data = Data(bytes: UnsafeRawPointer(ptr), count: Int(length))
            return FieldValue.binary(data)
        }
        
        func string() throws -> String {
            switch self {
            case .null:
                throw QueryError.resultParseError(message: "the field is not string.", result: "null")
            case .date(let string, _):
                return string
            case .binary(let data):
                guard let string = String(data: data, encoding: .utf8) else {
                    throw QueryError.resultParseError(message: "invalid utf8 string bytes.", result: "")
                }
                return string
            }
        }
    }
    
    fileprivate func query<T: Decodable>(query formattedQuery: String, option: QueryParameterOption) throws -> ([T], QueryStatus) {
        let (rows, status) = try self.query(query: formattedQuery, option: option)
        return try (rows.map({ try T(from: QueryRowResultDecoder(row: $0))}), status)
    }
    
    fileprivate func query(query formattedQuery: String, option: QueryParameterOption) throws -> ([QueryRowResult], QueryStatus) {
        let mysql = try connectIfNeeded()
        
        func queryPrefix() -> String {
            if self.option.omitDetailsOnError {
                return ""
            }
            return formattedQuery.subString(max: 1000)
        }
//        print("MySQL formattedQuery:\(formattedQuery)")
        guard mysql_real_query(mysql, formattedQuery, UInt(formattedQuery.utf8.count)) == 0 else {
            throw QueryError.queryExecutionError(message: MySQLUtil.getMySQLError(mysql), query: queryPrefix())
        }
        let status = QueryStatus(mysql: mysql)
        
        let res = mysql_use_result(mysql)
        guard res != nil else {
            if mysql_field_count(mysql) == 0 {
                // actual no result
                return ([], status)
            }
            throw QueryError.resultFetchError(message: MySQLUtil.getMySQLError(mysql), query: queryPrefix())
        }
        defer {
            mysql_free_result(res)
        }
        
        let fieldCount = Int(mysql_num_fields(res))
        guard fieldCount > 0 else {
            throw QueryError.resultNoFieldError(query: queryPrefix())
        }
        
        // fetch field info
        guard let fieldDef = mysql_fetch_fields(res) else {
            throw QueryError.resultFieldFetchError(query: queryPrefix())
        }
        var fields:[Field] = []
        for i in 0..<fieldCount {
            guard let f = Field(f: fieldDef[i]) else {
                throw QueryError.resultFieldFetchError(query: queryPrefix())
            }
            fields.append(f)
        }
        
        // fetch rows
        var rows:[QueryRowResult] = []
        
        var rowCount: Int = 0
        while true {
            guard let row = mysql_fetch_row(res) else {
                break // end of rows
            }
            
            guard let lengths = mysql_fetch_lengths(res) else {
                throw QueryError.resultRowFetchError(query: queryPrefix())
            }
            
            var fieldValues: [FieldValue] = []
            for i in 0..<fieldCount {
                let field = fields[i]
                if let valf = row[i], row[i] != nil {
                    let binary = FieldValue.makeBinary(ptr: valf, length: lengths[i])
                    if field.isDate {
                        fieldValues.append(FieldValue.date(dateString: try binary.string(), timezone: option.timeZone))
                    } else {
                        fieldValues.append(binary)
                    }                    
                } else {
                    fieldValues.append(FieldValue.null)
                }
                
            }
            rowCount += 1
            if fields.count != fieldValues.count {
                throw QueryError.resultParseError(message: "invalid fetched column count", result: "")
            }
            
            rows.append(QueryRowResult(fields: fields, fieldValues: fieldValues))
        }
        
        return (rows, status)
    }
    
    ///查询[[String : Any?]]类型结果
    fileprivate func queryJsonObjects_(query formattedQuery: String, option: QueryParameterOption) throws -> ([[String : Any?]], QueryStatus) {
        let mysql = try connectIfNeeded()
        
        func queryPrefix() -> String {
            if self.option.omitDetailsOnError {
                return ""
            }
            return formattedQuery.subString(max: 1000)
        }
        
        guard mysql_real_query(mysql, formattedQuery, UInt(formattedQuery.utf8.count)) == 0 else {
            throw QueryError.queryExecutionError(message: MySQLUtil.getMySQLError(mysql), query: queryPrefix())
        }
        let status = QueryStatus(mysql: mysql)
        
        let res = mysql_use_result(mysql)
        guard res != nil else {
            if mysql_field_count(mysql) == 0 {
                // actual no result
                return ([], status)
            }
            throw QueryError.resultFetchError(message: MySQLUtil.getMySQLError(mysql), query: queryPrefix())
        }
        defer {
            mysql_free_result(res)
        }
        
        let fieldCount = Int(mysql_num_fields(res))
        guard fieldCount > 0 else {
            throw QueryError.resultNoFieldError(query: queryPrefix())
        }
        
        // fetch field info
        guard let fieldDef = mysql_fetch_fields(res) else {
            throw QueryError.resultFieldFetchError(query: queryPrefix())
        }
        var fields:[Field] = []
        for i in 0..<fieldCount {
            guard let f = Field(f: fieldDef[i]) else {
                throw QueryError.resultFieldFetchError(query: queryPrefix())
            }
            fields.append(f)
        }
        
        // fetch rows
        var rows: [[String : Any?]] = []
        while true {
            
            guard let row = mysql_fetch_row(res) else {
                break // end of rows
            }
            
            guard let _ = mysql_fetch_lengths(res) else {
                throw QueryError.resultRowFetchError(query: queryPrefix())
            }
            let rowDic = try convertRowValueToDic(row: row, fields: fields, fieldCount: fieldCount)
            if fields.count != rowDic.count {
                throw QueryError.resultParseError(message: "invalid fetched column count", result: "")
            }
            rows.append(rowDic)
        }

        return (rows, status)
    }
    
    ///将数据库原始查询结果转换成[String : Any?]类型的结果
    private func convertRowValueToDic(row: MYSQL_ROW, fields: [Field], fieldCount: Int )throws ->[String : Any?]{
        var results: [String : Any?] = [ : ]
        for i in 0..<fieldCount {
            let field = fields[i]
            if let valf = row[i], row[i] != nil {
                let string = String(cString: valf)
                
                switch field.type {
                case MYSQL_TYPE_DECIMAL:
                    results[field.name] = try Decimal.fromSQLValue(string: string)
                case MYSQL_TYPE_TINY:
                    results[field.name] = (try Int.fromSQLValue(string: string)) == 1 ? true : false
                case MYSQL_TYPE_SHORT:
                    results[field.name] = try Int.fromSQLValue(string: string)
                case MYSQL_TYPE_LONG:
                    results[field.name] = try Int.fromSQLValue(string: string)
                case MYSQL_TYPE_FLOAT:
                    results[field.name] = try Float.fromSQLValue(string: string)
                case MYSQL_TYPE_DOUBLE:
                    results[field.name] = try Double.fromSQLValue(string: string)
                case MYSQL_TYPE_NULL:
                    results[field.name] = nil
                case MYSQL_TYPE_DATE, MYSQL_TYPE_DATETIME, MYSQL_TYPE_TIME, MYSQL_TYPE_TIMESTAMP:
                    results[field.name] = try Date(sqlDate: string, timeZone: option.timeZone)
                case MYSQL_TYPE_LONGLONG:
                    results[field.name] = try Int64.fromSQLValue(string: string)
                case MYSQL_TYPE_INT24:
                    results[field.name] = try Int.fromSQLValue(string: string)
                case MYSQL_TYPE_VAR_STRING, MYSQL_TYPE_STRING, MYSQL_TYPE_BLOB, MYSQL_TYPE_TINY_BLOB, MYSQL_TYPE_LONG_BLOB, MYSQL_TYPE_MEDIUM_BLOB:
                    results[field.name] = string
                case MYSQL_TYPE_JSON:
                    if let data = string.data(using: .utf8) {
                        let jsonObj = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
                        results[field.name] = jsonObj
                    }else{
                        throw QueryError.resultParseError(message: "Unsupported mysql type:\(field.type) field:\(field.name)", result: "")
                    }
                default:
                    throw QueryError.resultParseError(message: "Unsupported mysql type:\(field.type) field:\(field.name)", result: "")
                }
            }
            
        }
        return results
    }
}

fileprivate struct QueryParameterDefaultOption: QueryParameterOption {
    let timeZone: TimeZone
}


extension Connection {
    
    internal static func buildParameters(_ params: [QueryParameter], option: QueryParameterOption) throws -> [QueryParameterType] {
        return try params.map { try $0.queryParameter(option: option) }
    }
    
    public func query<R: Decodable>(_ query: String, _ params: [QueryParameter] = []) throws -> ([R], QueryStatus) {
        let option = QueryParameterDefaultOption(
            timeZone: self.option.timeZone
        )
        let queryString = try QueryFormatter.format(query: query, parameters: type(of: self).buildParameters(params, option: option))
        return try self.query(query: queryString, option: option)
    }
    
    public func query<R: Decodable>(_ query: String, _ params: [QueryParameter] = [], option: QueryParameterOption) throws -> ([R], QueryStatus) {
        let queryString = try QueryFormatter.format(query: query, parameters: type(of: self).buildParameters(params, option: option))
        return try self.query(query: queryString, option: option)
    }
    
    public func query<R: Decodable>(_ query: String, _ params: [QueryParameter] = []) throws -> [R] {
        let (rows, _) = try self.query(query, params) as ([R], QueryStatus)
        return rows
    }
    
    public func query<R: Decodable>(_ query: String, _ params: [QueryParameter] = [], option: QueryParameterOption) throws -> [R] {
        let (rows, _) = try self.query(query, params, option: option) as ([R], QueryStatus)
        return rows
    }
    
    public func query(_ query: String, _ params: [QueryParameter] = []) throws -> QueryStatus {
        let (_, status) = try self.query(query, params) as ([EmptyRowResult], QueryStatus)
        return status
    }
    
    public func query(_ query: String, _ params: [QueryParameter] = [], option: QueryParameterOption) throws -> QueryStatus {
        let (_, status) = try self.query(query, params, option: option) as ([EmptyRowResult], QueryStatus)
        return status
    }
}


extension Connection {
    
    public func queryJsonObjectsWithStatus(_ query: String, _ params: [QueryParameter]) throws -> ([[String : Any?]], QueryStatus) {
        let option = QueryParameterDefaultOption(
            timeZone: self.option.timeZone
        )
        let queryString = try QueryFormatter.format(query: query, parameters: type(of: self).buildParameters(params, option: option))
        return try self.queryJsonObjects_(query: queryString, option: option)
    }
    
    public func queryJsonObjectsWithStatusWithOption(_ query: String, _ params: [QueryParameter], option: QueryParameterOption) throws -> ([[String : Any?]], QueryStatus) {
        let queryString = try QueryFormatter.format(query: query, parameters: type(of: self).buildParameters(params, option: option))
        return try self.queryJsonObjects_(query: queryString, option: option)
    }
    
    public func queryJsonObjects(query: String, params: [QueryParameter]) throws -> [[String : Any?]] {
        let (rows, _) = try self.queryJsonObjectsWithStatus(query, params)
        return rows
    }
    
    public func queryJsonObjectsWithOption(query: String, params: [QueryParameter], option: QueryParameterOption) throws -> [[String : Any?]] {
        let (rows, _) = try self.queryJsonObjectsWithStatusWithOption(query, params, option: option)
        return rows
    }
}
