//
//  NetworkService.swift
//  ModernSwiftNetworking
//
//  Created by Ansyar Hafid on 25/10/24.
//

import Foundation
import Combine

public struct NetworkService: @unchecked Sendable {
    public static let shared = NetworkService()
    
    public func request<T: Decodable>(_ target: TargetType, decodingType: T.Type) -> AnyPublisher<T, Error> {
        let request = buildRequest(from: target)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
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
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        return urlRequest
    }
}
