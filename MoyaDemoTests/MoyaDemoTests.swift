//
//  MoyaDemoTests.swift
//  MoyaDemoTests
//
//  Created by Mustafa on 11/8/17.
//  Copyright © 2017 Mustafa. All rights reserved.
//

import XCTest
import OHHTTPStubs
import Moya
import RxSwift

@testable import MoyaDemo

class MoyaDemoTests: XCTestCase {
    
    let disposeBag = DisposeBag()
    override func setUp() {
        super.setUp()

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        OHHTTPStubs.removeAllStubs()

    }
    
    func testNormalPosts() {
        
        let expectationResult = expectation(description: "Normal posts")

        
        Provider.rx.request(.allposts)
            .filterSuccessfulStatusCodes()
            .map([Post].self)
            .subscribe(onSuccess: { posts in
                print("Posts \(posts)")
                expectationResult.fulfill()

            }) { error in
                print("Error happened: \(error)")
        }.disposed(by: disposeBag)
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testFailedPosts() {
        let expectationResult = expectation(description: "Failed posts")
        
        stub(condition: isPath("/tosbaha/MoyaDemo/login"))
        { (request) -> OHHTTPStubsResponse in
            let stubPath = OHPathForFile("login.json", type(of: self))
            return fixture(filePath: stubPath!, status: 200, headers: ["Content-Type":"application/json"])
        }
        
        var counter = 0
        var status:Int32 = 200
        var stubPath:String?
        stub (condition:isPath("/tosbaha/MoyaDemo/posts"))
        { request -> OHHTTPStubsResponse in
            if counter < 1 {
                print("It is failed response!")
                stubPath = OHPathForFile("noauth.json", type(of: self))
                status = 401
                counter += 1
            } else {
                stubPath = OHPathForFile("allposts.json", type(of: self))
                status = 200
                print("It is normal response!")
            }
            return fixture(filePath: stubPath!, status: status, headers: ["Content-Type":"application/json"])
        }

        
        Provider.rx.request(.allposts)
            .filterSuccessfulStatusCodes()
            .retryWithAuthIfNeeded(limit:3)
            .map([Post].self)
            .subscribe(onSuccess: { posts in
                print("Posts \(posts)")
                expectationResult.fulfill()
                
            }) { error in
                print("Error happened: \(error)")
            }.disposed(by: disposeBag)
        waitForExpectations(timeout: 3, handler: nil)

        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
