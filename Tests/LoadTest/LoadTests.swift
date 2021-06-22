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
}
