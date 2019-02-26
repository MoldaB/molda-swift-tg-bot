//
//  MovieInfo.swift
//  App
//
//  Created by Beygel on 26/02/2019.
//

import Foundation

struct MovieInfo
{
    let title: String
    let year: Int
    let runtime: Int
    let genres: [String]
    let directors: [String]
    let actors: [String]
    let plot: String
    let poster: String
}

extension MovieInfo: CustomStringConvertible
{
    var description: String {
        return """
        Title: \(title)
        Year: \(year)
        Time: \(runtime) min
        Generes: \(genres.joined(separator: ", "))
        Directors: \(directors.joined(separator: ", "))
        Actors: \(actors.joined(separator: ", "))
        """
    }
}

extension MovieInfo: Decodable
{
    enum CodingKeys: String, CodingKey
    {
        case Title, Year, Runtime, Genre, Director, Actors, Plot, Poster
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .Title)
        let yearString = try container.decode(String.self, forKey: .Year)
        let runtimeString = try container.decode(String.self, forKey: .Runtime).replacingOccurrences(of: " min", with: "")
        let genresString = try container.decode(String.self, forKey: .Genre)
        let directorsString = try container.decode(String.self, forKey: .Director)
        let actorsString = try container.decode(String.self, forKey: .Actors)
        self.year = Int(yearString) ?? -1
        self.runtime = Int(runtimeString) ?? -1
        self.genres = genresString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        self.directors = directorsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        self.actors = actorsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        self.plot = try container.decode(String.self, forKey: .Plot)
        self.poster = try container.decode(String.self, forKey: .Poster)
    }
}


