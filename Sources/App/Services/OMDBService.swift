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
    private let endPoint = "http://www.omdbapi.com/?apikey=fd7988cb"
    private var API_KEY: String { return "fd7988cb" }
    init() {
        
    }
    
    func searchMovie(name: String, handler: @escaping NetworkResponseHandler<[MovieResult]>) {
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "http"
        urlComponents.host = "www.omdbapi.com"
        urlComponents.path = "/"
        // add params
        let movieNameQuery = URLQueryItem(name: "s", value: name)
        let apiKeyQuery = URLQueryItem(name: "apikey", value: API_KEY)
        urlComponents.queryItems = [movieNameQuery, apiKeyQuery] as [URLQueryItem]

        guard let urlPath = urlComponents.url else {
            return
        }
        URLSession.shared.dataTask(with: urlPath) { (data, response, error) in
            defer {
                if let error = error {
                    NSLog("ERROR - ", error.localizedDescription)
                }
            }
            guard let responseData = data else {
                handler(nil, ServiceError.dataIsNull)
                return
            }
            do {
                let decoder = JSONDecoder()
                let searchResult = try decoder.decode(SearchResponse<MovieResult>.self, from: responseData)
                let movies = searchResult.search
                handler(movies, nil)
            } catch {
                handler(nil, ServiceError.parsing(error: error))
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
