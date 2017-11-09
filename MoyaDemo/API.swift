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
    /// Tries to refresh auth token on 401 errors and retry the request.
    /// If the refresh fails, the signal errors.
    public func retryWithAuthIfNeeded() ->  Single<Response> {
        return self.retryWhen{ (e: Observable<Error>) in
            Observable.zip(e, Observable.range(start: 1, count: 3), resultSelector: { $1 })
                .flatMap { i in
                    return Provider.rx.request(.login(email: "abc@def.com",password:"secret"))
                        .filterSuccessfulStatusAndRedirectCodes()
                        .map(Token.self)
                        .catchError {  error  in
                            if case MoyaError.statusCode(let response) = error  {
                                if response.statusCode == 401 {
                                    // Logout
                                    do {
                                        try UserService.logOut()
                                    } catch _ {
                                        print("Failed to logout")
                                    }
                                }
                            }
                            return Single.error(error)
                        }.flatMap { token -> Single<Token> in
                            do {
                                try token.saveInRealm()
                            } catch let e {
                                print("Failed to save access token")
                                return Single.error(e)
                            }
                            return Single.just(token)
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
