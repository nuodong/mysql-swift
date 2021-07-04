// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "mysql-swift",
    products: [
        .library(name: "MySQL", targets: ["MySQL"])
    ],
    targets: [
        .systemLibrary(
            name: "CMySQL",
            path: "Sources/cmysql",
            pkgConfig: "mysqlclient"
        ),

        .target(
            name: "MySQL",
            dependencies: [
                "CMySQL",
            ]
        ),
//        .testTarget(
//            name: "MySQLTests",
//            dependencies: [
//                "MySQL"
//            ]
//        ),
//        .testTarget(
//            name: "SQLFormatterTests",
//            dependencies: [
//                "MySQL"
//            ]
//        ),
        .testTarget(
            name: "LoadTest",
            dependencies: [
                "MySQL"
            ]
        )
    ]
)
