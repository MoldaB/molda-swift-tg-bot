//
//  OMDBService.swift
//  App
//
//  Created by Beygel on 13/02/2019.
//

import Foundation

final class OMDBService
{
    private let queue = DispatchQueue(label: "omdb-queue", qos: .background)
    private var endPointComponents: URLComponents {
        var urlComponents = URLComponents()
        urlComponents.scheme = "http"
        urlComponents.host = "www.omdbapi.com"
        urlComponents.path = "/"
        return urlComponents
    }
    private var API_KEY: String { return "fd7988cb" }
    init() {}
    
    func searchMovie(name: String, handler: @escaping NetworkResponseHandler<[MovieResult]>) {
        var endPoint = endPointComponents
        let movieNameQuery = URLQueryItem(name: "s", value: name)
        let apiKeyQuery = URLQueryItem(name: "apikey", value: API_KEY)
        endPoint.queryItems = [movieNameQuery, apiKeyQuery] as [URLQueryItem]

        guard let urlPath = endPoint.url else {
            handler(.failure(nil))
            return
        }
        URLSession.shared.dataTask(with: urlPath) { (data, response, error) in
            defer {
                if let error = error {
                    NSLog("ERROR - \(error)")
                }
            }
            guard let responseData = data else {
                handler(.failure(ServiceError.dataIsNull))
                return
            }
            do {
                let decoder = JSONDecoder()
                let searchResult = try decoder.decode(SearchResponse<MovieResult>.self, from: responseData)
                let movies = searchResult.search
                handler(.success(movies))
            } catch {
                handler(.failure(ServiceError.parsing(error: error)))
            }
        }.resume()
    }
    
    func getInformation(for movieId: String, handler: @escaping NetworkResponseHandler<MovieInfo>) {
        var endPoint = endPointComponents
        endPoint.queryItems = [
            URLQueryItem(name: "i", value: movieId),
            URLQueryItem(name: "apikey", value: API_KEY)
        ]
        
        guard let urlPath = endPoint.url else {
            handler(.failure(nil))
            return
        }
        URLSession.shared.dataTask(with: urlPath) { (data, response, error) in
            defer {
                if let error = error {
                    NSLog("ERROR - \(error)")
                }
            }
            guard let responseData = data else {
                handler(.failure(ServiceError.dataIsNull))
                return
            }
            do {
                let decoder = JSONDecoder()
                let movie = try decoder.decode(MovieInfo.self, from: responseData)
                handler(.success(movie))
            } catch {
                handler(.failure(ServiceError.parsing(error: error)))
            }
            }.resume()
        
    }
}

extension OMDBService
{
    indirect enum ServiceError: Swift.Error
    {
        case dataIsNull
        case parsing(error: Swift.Error?)
    }
}

extension OMDBService
{
    struct SearchResponse<Searched>
    {
        let search: [Searched]
        let totalResults: Int
        let response: Bool
        
        init(search: [Searched], totalResults: Int, response: Bool) {
            self.search = search
            self.totalResults = totalResults
            self.response = response
        }
    }
}

extension OMDBService.SearchResponse: Decodable where Searched: Decodable
{
    enum CodingKeys: String, CodingKey
    {
        case Search, totalResults, Response
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let search = try container.decode([Searched].self, forKey: .Search)
        let totalResults = try container.decode(String.self, forKey: .totalResults)
        let response = try container.decode(String.self, forKey: .Response)
        self.init(search: search, totalResults: Int(totalResults) ?? 0, response: Bool(response) ?? false)
    }
}
