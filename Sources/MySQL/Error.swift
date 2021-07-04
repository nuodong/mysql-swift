//
//  Error.swift
//  MySQL
//
//  Created by Yusuke Ito on 12/14/15.
//  Copyright © 2015 Yusuke Ito. All rights reserved.
//
public protocol MySQLError: Error {
    
}

public enum MySQLConnectionError: MySQLError {
    case connectionError(String)
    case connectionPoolGetConnectionTimeoutError
}

public enum MySQLQueryError: MySQLError {
    
    case queryExecutionError(message: String, query: String)
    case resultFetchError(message: String, query: String)
    case resultNoFieldError(query: String)
    case resultRowFetchError(query: String)
    case resultFieldFetchError(query: String)
    case resultParseError(message: String, result: String)
    
    case resultCastError(actualValue: String, expectedType: String, forField: String)
    case resultDecodeError(rawSQLValue: String, forType: Any)
    case resultDecodeErrorMessage(message: String)
    case SQLDateStringError(String)
    case SQLRawStringDecodeError(error: Error, actualValue: String, expectedType: String, forField: String)
    
    case missingField(String)
}

public enum MySQLQueryParameterError: MySQLError {
    case dateComponentsError(String)
}

public enum MySQLQueryFormatError: MySQLError {
    case placeholderCountMismatch(query: String)
    case parameterIDTypeError(givenValue: String, query: String)
}
