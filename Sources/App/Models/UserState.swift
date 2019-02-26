//
//  UserState.swift
//  App
//
//  Created by Beygel on 13/02/2019.
//

import Foundation

final class UserState
{
    let id: Int64
    var movieResults: [MovieResult]?
    var presentedMovieResultIndex: Int?
    var location: Path
    var chatId: Int64
    var pickedRating: Int?
    
    var presentedMovie: MovieResult? {
        if let index = presentedMovieResultIndex {
            return movieResults?[index]
        }
        return nil
    }
    
    var pickedMovie: MovieInfo?
    
    init(id: Int64, chatId: Int64, movieResults: [MovieResult]? = nil, location: Location = .initial) {
        self.id = id
        self.chatId = chatId
        self.movieResults = movieResults
        self.location = [location]
    }
}

extension UserState
{
    typealias Path = [Location]
    
    enum Location
    {
        case initial, movie, series, recipes, music
        case name, rate, description, url
    }
}

extension Array where Element == UserState.Location
{
    mutating func following(_ location: UserState.Location) {
        self.append(location)
    }
}
