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
    var location: Location
    var chatId: Int64
    
    init(id: Int64, chatId: Int64, movieResults: [MovieResult]? = nil, location: Location = .initial) {
        self.id = id
        self.chatId = chatId
        self.movieResults = movieResults
        self.location = location
    }
}

extension UserState
{
    enum Location
    {
        case initial, movie
    }
}
