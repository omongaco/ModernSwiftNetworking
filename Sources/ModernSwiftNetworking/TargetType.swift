//
//  TargetType.swift
//  ModernSwiftNetworking
//
//  Created by Ansyar Hafid on 25/10/24.
//

import Foundation

public protocol TargetType {
    var baseURL: URL { get }
    var path: String { get }
    var method: String { get }
    var parameters: [String: Any]? { get }
    var headers: [String: String]? { get }
    var task: Task { get }
}

public enum Task {
    case requestPlain
    case requestParameters(parameters: [String: Any], encoding: ParameterEncoding)
}

public enum ParameterEncoding {
    case url
    case json
}
