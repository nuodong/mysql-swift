//
//  LoadTests.swift
//  
//
//  Created by Wang Yong on 2021/6/22.
//

import XCTest
import Foundation
import Dispatch

@testable import MySQL

class LoadTests: XCTestCase {
    
    struct Option: ConnectionOption {
        let host: String = "rm-m5eknj9wl2qv48vm8so.mysql.rds.aliyuncs.com"
        let port: Int = 3306
        let user: String = "dev"
        let password: String = "Nurdsdev!"
        let database: String = "dev-barcode"
        
    }
    var pool = ConnectionPool(option: Option())
    
    func testQueryJsonObject() throws {
        let countRows: [[String : Any?]] = try self.pool.execute({ conn in
            let sql = "SELECT count(*) as count_id FROM TableChangeTag WHERE team_id = ? and id > ? and recordType = ?"
            return try conn.queryJsonObjects(query: sql, params: [89754, 0, "BarcodeDataTable"])
        })
        print("countRows:\(countRows)")
    }
    
    final class NUDevice: Codable {
        
        var id: Int?
        var udid: String
        var info: DeviceInfoRequestModel
        var apnsToken: String
        var lastLoginTime: Date?
        var lastUpdate: Date?
        var createTime: Date?
        var user_id: Int?
        

    }
    class DeviceInfoRequestModel:  Codable, QueryParameter{
        
        var sys_os: String?
        var sys_UDID: String?
        var sys_model: String?
        var sys_locale: String?
        var sys_channel: String?
        var sys_language: String?
        var sys_user_pid: String?
        var sys_timeStamp: String?
        var sys_appVersion: String?
        var sys_cfBundleId: String?
        var sys_deviceName: String?
        var sys_systemName: String?
        var sys_systemVersion: String?
        var sys_localizedModel: String?
        var sys_userInterfaceIdiom: String?
        
        public func queryParameter(option: QueryParameterOption)throws -> QueryParameterType {
            let data = try JSONEncoder().encode(self)
            guard let string = String(data: data, encoding: .utf8) else { throw MySQLQueryFormatError.placeholderCountMismatch(query: "ddddddddd") }
            return EscapedQueryParameter("'\(string)'")
        }
    }

    func testQueryModel() throws {
        let devices: [NUDevice] = try self.pool.execute({ conn in
            let sql = "select *from device limit 1"
            return try conn.query(sql)
        })
        print("devices:\(devices)")
    }
}
