//
//  Movie.swift
//  App
//
//  Created by Beygel on 13/02/2019.
//

import Foundation

struct MovieResult
{
    let id: String
    let name: String
    let year: Int
    let poster: String
    
    init(id: String, name: String, year: Int, poster: String) {
        self.id = id
        self.name = name
        self.year = year
        self.poster = poster
    }
}

// MARK: - Equatable
extension MovieResult: Equatable
{
    public static func == (lhs: MovieResult, rhs: MovieResult) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Decodable
extension MovieResult: Decodable
{
    /*
     {
     "Title":"The Matrix",
     "Year":"1999"
     imdbID":"tt0133093"
     Type":"movie"
     Poster":"https://m.media-amazon.com/images/M/MV5BNzQzOTk3OTAtNDQ0Zi00ZTVkLWI0MTEtMDllZjNkYzNjNTc4L2ltYWdlXkEyXkFqcGdeQXVyNjU0OTQ0OTY@._V1_SX300.jpg"
     }
     */
    enum CodingKeys: String, CodingKey
    {
        case imdbID, Title, Year, Poster
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .imdbID)
        let name = try container.decode(String.self, forKey: .Title)
        let year = try container.decode(String.self, forKey: .Year)
        let poster = try container.decodeIfPresent(String.self, forKey: .Poster) ?? ""
        self.init(id: id, name: name, year: Int(year) ?? -1, poster: poster)
        
    }
}

