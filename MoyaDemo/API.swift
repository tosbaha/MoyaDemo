//
//  API.swift
//  MoyaDemo
//
//  Created by Mustafa on 11/8/17.
//  Copyright © 2017 Mustafa. All rights reserved.
//

import Foundation
import RxSwift
import Moya

extension PrimitiveSequence where TraitType == SingleTrait, ElementType == Response {
    /// Try maximum `limit` times. if status is 401 first refresh the receipt
    /// If error code is not 401 try again with limit
    /// - Parameter limit: how many tries
    /// - Returns: Single Response
    public func retryWithAuthIfNeeded(limit:Int) -> Single<E> {
        return self.retryWhen{ errors in
            return errors.enumerated().flatMap{ (retryCount, error) -> Single<String> in
                print("Retry Count: \(retryCount)")
                // We can retry with and without token maximum `limit` times!
                if retryCount < limit {
                    // we will decide what kind of error it is
                    // if it is 401 we will try with refresh
                    if  case MoyaError.statusCode(let response) = error, response.statusCode == 401 {
                        print("Error is 401 we should try with Refresh")
                        return Provider.rx.request(.login(email: "abc@def.com",password:"secret"))
                            .filterSuccessfulStatusAndRedirectCodes()
                            .map(Token.self)
                            .catchError { error -> Single<Token> in
                                print("Error refreshing token")
                                // Try once again if we have the user
                                if let user = UserService.sharedInstance.getUser() {
                                    return Single.just(Token(token: user.token))
                                }
                                // Suck it! we don't have the user. Return the error!
                                throw error
                            }.flatMap {user -> Single<String> in
                                do {
                                    try user.saveInRealm()
                                } catch let e {
                                    print("Failed to save access token")
                                    return Single.error(e)
                                }
                                return Single.just(user.token)
                        }
                        
                        // Another Error
                    } else {
                        print("This is another server error")
                        // If we have the user lets try again
                        if let user = UserService.sharedInstance.getUser() {
                            return Single.just(user.token)
                        }
                        // Suck it! we don't have the user. Return the error!
                        throw error
                    }
                } else {
                    // End of the Road
                    print("We tried as much as we can")
                    throw error
                }
            }
        }
    }
}


private let endpointClosure = { (target: MyAPI) -> Moya.Endpoint<MyAPI> in
    
    let endpoint = MoyaProvider.defaultEndpointMapping(for: target);
    
    switch target {
     //Don't add token for this endpoints
    case .register,.login:
        return endpoint
    default:
    //If there is a token add a token to header
        if let token = UserService.sharedInstance.getUser()?.token {
            return endpoint.adding(newHTTPHeaderFields:["X-Api-Token": token])
        } else {
            return endpoint

        }
    }
}

private func JSONResponseDataFormatter(_ data: Data) -> Data {
    do {
        let dataAsJSON = try JSONSerialization.jsonObject(with: data)
        let prettyData =  try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
        return prettyData
    } catch {
        return data // fallback to original data if it can't be serialized.
    }
}

let Provider = MoyaProvider<MyAPI>(endpointClosure:endpointClosure,plugins: [NetworkLoggerPlugin(verbose: true, responseDataFormatter: JSONResponseDataFormatter)])

enum MyAPI {
    //User management
    case register(email:String,password:String)
    case login(email:String,password:String)
    
    
    //Posts functions
    case allposts
    case post(id:String)
    
}

extension MyAPI:TargetType {
    
    var task: Moya.Task {
        return .requestParameters(parameters: parameters ?? [:], encoding: parameterEncoding)
    }
    
    var headers: [String : String]? {
        return nil
    }
    
    var baseURL: URL { return URL(string: "https://my-json-server.typicode.com/tosbaha/MoyaDemo")! }
    var path:String {
        switch self {
        case .register:
            return "/register"
        case .login:
            return "/login"
        case .allposts:
            return "/posts"
        case .post(let id):
            return "/posts\(id)"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .register:
            return .post
        case .login:
            return .post
        case .allposts:
            return .get
        case .post:
            return .get
        }
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .login(let email,let password):
            return ["email":email,"password":password]
        case .register(let email,let password):
            return ["email":email,"password":password]
        default:
            return nil
        }
    }
    
    public var parameterEncoding: ParameterEncoding {
        return JSONEncoding.default
    }
    
    var sampleData:Data {
            return Data()
    }
}
