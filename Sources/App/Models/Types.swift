//
//  Types.swift
//  App
//
//  Created by Beygel on 13/02/2019.
//


enum NetworkResponse<ResponseType>
{
    case success(_ data: ResponseType)
    case failure(_ error: Error?)
}

typealias NetworkResponseHandler<T> = (NetworkResponse<T>) -> ()

import Foundation

enum Logger: String
{
    case network
    case movies
    case omdb
    case general
    case command
    
    private var path: String {
        return rawValue.capitalized
    }
    
    private var logLine: String {
        return "------------------"
    }
    
    
    func log(message: String, for userId: String) {
        NSLog(["\n", logLine, "user id - \(userId)", "\(path) - \(message)", logLine].joined(separator: "\n"))
    }
    
    func log(error: Error, result: String = "", for userId: String) {
        log(message: "ERROR - \(result): \(error)", for: userId)
    }
    
    func log(errorMessage: String, result: String = "", for userId: String) {
        log(message: "ERROR - \(result): \(errorMessage)", for: userId)
    }
}
