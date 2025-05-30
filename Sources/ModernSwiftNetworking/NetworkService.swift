//
//  NetworkService.swift
//  ModernSwiftNetworking
//
//  Created by Ansyar Hafid on 25/10/24.
//

import Foundation
import Combine

public enum ErrorResponse: Error {
    case invalidResponse(statusCode: Int)
    case emptyData(statusCode: Int)
    case decodingError(underlying: Error, statusCode: Int)
}

public struct NetworkService: @unchecked Sendable {
    public static let shared = NetworkService()
    
    public func request<T: Decodable>(_ target: TargetType, decodingType: T.Type) -> AnyPublisher<T, ErrorResponse> {
        let request = buildRequest(from: target)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { error in
                ErrorResponse.invalidResponse(statusCode: -1)
            }
            .tryMap { data, response -> (Data, HTTPURLResponse) in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ErrorResponse.invalidResponse(statusCode: -1)
                }
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw ErrorResponse.invalidResponse(statusCode: httpResponse.statusCode)
                }
                return (data, httpResponse)
            }
            .mapError { error in
                error as? ErrorResponse ?? ErrorResponse.invalidResponse(statusCode: -1)
            }
            .flatMap { data, httpResponse -> AnyPublisher<T, ErrorResponse> in
                // Handle empty response with EmptyResponse
                if data.isEmpty {
                    // Attempt to return an empty instance of T if possible
                    if let emptyInstance = try? JSONDecoder().decode(T.self, from: "{}".data(using: .utf8)!) {
                        return Just(emptyInstance)
                            .setFailureType(to: ErrorResponse.self)
                            .eraseToAnyPublisher()
                    } else {
                        return Fail(error: ErrorResponse.emptyData(statusCode: httpResponse.statusCode))
                            .eraseToAnyPublisher()
                    }
                }
                
                // Check if the decodingType is Data itself
                if decodingType == Data.self, let castedData = data as? T {
                    return Just(castedData)
                        .setFailureType(to: ErrorResponse.self)
                        .eraseToAnyPublisher()
                }

                // Otherwise, decode normally
                return Just(data)
                    .decode(type: T.self, decoder: JSONDecoder())
                    .mapError { error in
                        ErrorResponse.decodingError(underlying: error, statusCode: httpResponse.statusCode)
                    }
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func buildRequest(from target: TargetType) -> URLRequest {
        var urlRequest = URLRequest(url: target.baseURL.appendingPathComponent(target.path))
        urlRequest.httpMethod = target.method.uppercased()
        urlRequest.allHTTPHeaderFields = target.headers
        
        switch target.task {
        case .requestPlain:
            break
        case .requestParameters(let parameters, let encoding):
            switch encoding {
            case .url:
                let queryParams = parameters.map{"\($0)=\($1)"}.joined(separator: "&")
                urlRequest.url = URL(string: "\(target.baseURL.appendingPathComponent(target.path))?\(queryParams)")
            case .json:
                urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])
            }
        }
        
        return urlRequest
    }
}
