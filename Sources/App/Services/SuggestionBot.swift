//
//  EchoBot.swift
//  EchoBot
//
//  Created by Givi Pataridze on 31.05.2018.
//

import Foundation
import Telegrammer
import Vapor



/// Bot for suggesting stuff
///
/// the bot flow goes like this:
/// 1. send /start action
/// 2. bot sends: "Try new commands\n/movie for suggesting movies,\n/series for suggesting searies,\n/recipes for suggesting food,\n/music for suggesting a new song\nenjoy."
///    * for now only movies will be valid
/// 3. user types /movie and the movie's name.
/// 4. bot sends an http request to omdb with given api key for retrieving movies list.
/// 5. movies list is presented in an inline message - movie + choose + next button + back button (else if first or last than buttons change accordingly)
/// 6. bot sends message - movie was picked please enter suggestion string
/// 7. bot sends inline message - please select rating
/// 8. bot sends summary as the preview message with submit key
///
final class SuggestionBot: ServiceType {
    
    let bot: Bot
    var updater: Updater?
    var dispatcher: Dispatcher?
    
    /// Dictionary for user echo modes
    lazy var userStates = [Int64: UserState]()
    
    ///Conformance to `ServiceType` protocol, fabric methhod
    static func makeService(for worker: Container) throws -> SuggestionBot {
        guard let token = Environment.get("TELEGRAM_BOT_TOKEN") else {
            throw CoreError(identifier: "Enviroment variables", reason: "Cannot find telegram bot token")
        }
        
        let settings = Bot.Settings(token: token, debugMode: true)
        
        /// Setting up webhooks https://core.telegram.org/bots/webhooks
        /// Internal server address (Local IP), where server will starts
        // settings.webhooksIp = "127.0.0.1"
        
        /// Internal server port, must be different from Vapor port
        // settings.webhooksPort = 8181
        
        /// External endpoint for your bot server
        // settings.webhooksUrl = "https://website.com/webhooks"
        
        /// If you are using self-signed certificate, point it's filename
        // settings.webhooksPublicCert = "public.pem"
        
        return try SuggestionBot(settings: settings)
    }
    
    init(settings: Bot.Settings) throws {
        self.bot = try Bot(settings: settings)
        let dispatcher = try configureDispatcher()
        self.dispatcher = dispatcher
        self.updater = Updater(bot: bot, dispatcher: dispatcher)
    }
    
    /// Initializing dispatcher, object that receive updates from Updater
    /// and pass them throught handlers pipeline
    func configureDispatcher() throws -> Dispatcher {
        ///Dispatcher - handle all incoming messages
        let dispatcher = Dispatcher(bot: bot)
        
        ///Creating and adding handler for command /echo
        let commandHandler = CommandHandler(commands: ["/start","/movie"], callback: recievedCommandUpdate)
        dispatcher.add(handler: commandHandler)
        
        ///Creating and adding handler for ordinary text messages
        let echoHandler = MessageHandler(filters: .text, callback: recivedMessageHandlerUpdate)
        dispatcher.add(handler: echoHandler)
        
        return dispatcher
    }
}


extension SuggestionBot {
    
    /// Command type enum
    ///
    /// - echo: /echo command
    /// - search: /search command
    enum Command
    {
        case start
        case movie(name: String)
        
        init?(commandString: String?) {
            guard let string = commandString else { return nil }
            var command = string
            // seperate if more than command
            // example: /start, /movie the matrix
            if let seperatorIndex = string.firstIndex(of: " ") {
                command = String(string.prefix(upTo: seperatorIndex))
            }
            switch command {
            case "/start":
                self = .start
            case "/movie":
                let movieName = string.replacingOccurrences(of: command, with: "").trimmingCharacters(in: .whitespaces)
                self = .movie(name: movieName)
            default:
                return nil
            }
        }
    }
    
    /// handles recieved command update in bot context
    ///
    /// - Parameters:
    ///   - update: bot update
    ///   - context: bot context
    /// - Throws: error while handling command
    func recievedCommandUpdate(_ update: Update, in context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        
        guard let command = Command(commandString: message.text) else {
            Logger.command.log(errorMessage: "\(message) command not found", for: String(user.id))
            return
        }
        // register user
        userStates[user.id] = UserState(id: user.id, chatId: message.chat.id)
        // handle command types
        switch command {
        case .start:
            try handleStartCommand(with: message, for: user, in: context)
        case .movie(let name):
            try handleMovieCommand(for: name, with: message, for: user, in: context)
        }
    }
    
    func recivedMessageHandlerUpdate(_ update: Update, in context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from,
            let _ = userStates[user.id] else { return }
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: message.text!)
        try bot.sendMessage(params: params)
    }
    
    /// handles suggestion command message for sending user in bot context
    ///
    /// - Parameters:
    ///   - message: sent by the user with the suggest command.
    ///   - user: sending party of the message
    ///   - context: BotContext or whatever
    /// - Throws: exeption if something else throws exception
    private func handleStartCommand(with message: Message, for user: User, in context: BotContext?) throws {
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id),
                                           text: "Try new commands\n/movie for suggesting movies,\n/series for suggesting searies,\n/recipes for suggesting food,\n/music for suggesting a new song\nenjoy.")
        try bot.sendMessage(params: params)
    }
}

// MARK: - Movie Command Handling
extension SuggestionBot
{
    
    /// <#Description#>
    ///
    /// - Parameters:
    ///   - movie: <#movie description#>
    ///   - message: <#message description#>
    ///   - user: <#user description#>
    ///   - context: <#context description#>
    /// - Throws: <#throws value description#>
    func handleMovieCommand(for movie: String, with message: Message, for user: User, in context: BotContext?) throws {
        // setup callback handlers
        setupMovieCallbacksHandler()
        // check that data was inputed
        let omdbClient = OMDBService()
        omdbClient.searchMovie(name: movie) {
            (movies, error) in
            defer {
                if let error = error {
                    Logger.omdb.log(error: error, result: "", for: String(user.id))
                }
            }
            guard let results = movies else { return }
            self.handleMovieResults(results, for: user, in: message.chat)
        }
    }
    
    /// <#Description#>
    ///
    /// - Parameters:
    ///   - results: <#results description#>
    ///   - user: <#user description#>
    ///   - context: <#context description#>
    private func handleMovieResults(_ results: [MovieResult], for user: User, in chat: Chat) {
        userStates[user.id]?.movieResults = results
        userStates[user.id]?.location = .movie
        guard let firstMovie = results.first else {
            NSLog("No movie was found - sending message to user")
            do {
                try sendNoMoviesFound(for: user, in: chat)
            } catch {
                Logger.movies.log(error: error, result: "sending no movies found message failed", for: String(user.id))
            }
            return
        }
        do {
            userStates[user.id]?.presentedMovieResultIndex = 0
            try showMessage(for: firstMovie, for: user, in: chat)
        } catch {
            Logger.movies.log(error: error, result: "send movie message failed", for: String(user.id))
        }
    }
    
    /// Shows reply message for given movie. should have next button
    ///
    /// - Parameters:
    ///   - movie: given movie
    ///   - user: user object
    /// - Throws: some error if bot failed saving
    private func showMessage(for movie: MovieResult, for user: User, in chat: Chat) throws {
        // setup keys and keyboard markup
        let thisIsItButton = InlineKeyboardButton(text: "this is it".capitalized,
                                                  callbackData: "this_is_it_movie")
        let nextButton = InlineKeyboardButton(text: "next".capitalized,
                                              callbackData: "next_movie")
        let previousButton = InlineKeyboardButton(text: "previous".capitalized,
                                                  callbackData: "previous_movie")
        // use relevant keys
        var keys = [thisIsItButton]
        guard let results = userStates[user.id]?.movieResults else {
            return
        }
        
        if movie != results.last {
            keys.append(nextButton)
        }
        
        if movie != results.first {
            keys.append(previousButton)
        }
        
        let keyboard = ReplyMarkup.inlineKeyboardMarkup(.init(inlineKeyboard: [[thisIsItButton], [nextButton], [previousButton]]))
        // setup message text
        let messageText = ["Is this the movie you ment?","name - \(movie.name)","Year - \(movie.year)"].joined(separator: "\n")
        // setup Photo message params
        let photoParams = Bot.SendPhotoParams(chatId: .chat(chat.id),
                                              photo: .url(movie.poster),
                                              caption: messageText,
                                              replyMarkup: keyboard)
        // send image
        try bot.sendPhoto(params: photoParams)
    }
    
    private func sendNoMoviesFound(for user: User, in chat: Chat) throws {
        let messageParams = Bot.SendMessageParams(chatId: .chat(chat.id), text: "No Movies by that name was found, try again.")
        try bot.sendMessage(params: messageParams)
    }
    
    // MARK: CallbackQueryHandlers
    private func setupMovieCallbacksHandler() {
        let thisIsItCallbackQueryHandler = CallbackQueryHandler(pattern: "this_is_it_movie", callback: handleThisIsItQueryUpdate)
        dispatcher?.add(handler: thisIsItCallbackQueryHandler)
        
        let nextCallbackQueryHandler = CallbackQueryHandler(pattern: "next_movie", callback: handleNextItQueryUpdate)
        dispatcher?.add(handler: nextCallbackQueryHandler)
        
        let previousCallbackQueryHandler = CallbackQueryHandler(pattern: "previous_movie", callback: handlePreviousQueryUpdate)
        dispatcher?.add(handler: previousCallbackQueryHandler)
    }
    
    private func handleThisIsItQueryUpdate(_ update: Update, in context: BotContext?) throws {
        guard let message = update.callbackQuery?.message,
            let user = update.callbackQuery?.from else { return }
        // get current presented movie index
        guard let presentedMovieResultIndex = userStates[user.id]?.presentedMovieResultIndex else { return }
        // get current presented movie
        guard let movie = userStates[user.id]?.movieResults?[presentedMovieResultIndex] else { return }
        // send picked 'movie name' message to user
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "You picked - \(movie.name)")
        try bot.sendMessage(params: params)
    }
    
    private func handleNextItQueryUpdate(_ update: Update, in context: BotContext?) throws {
        guard let message = update.callbackQuery?.message,
            let user = update.callbackQuery?.from else { return }
        // get current presented movie index
        guard let presentedMovieResultIndex = userStates[user.id]?.presentedMovieResultIndex else { return }
        // get next presented movie
        guard let index = userStates[user.id]?.presentedMovieResultIndex,
            let movie = userStates[user.id]?.movieResults?[index + 1] else { return }
        userStates[user.id]?.presentedMovieResultIndex = index + 1
        try showMessage(for: movie, for: user, in: message.chat)
    }
    
    private func handlePreviousQueryUpdate(_ update: Update, in context: BotContext?) throws {
        guard let message = update.callbackQuery?.message,
            let user = update.callbackQuery?.from else { return }
        // get current presented movie index
        guard let presentedMovieResultIndex = userStates[user.id]?.presentedMovieResultIndex else { return }
        // get next presented movie
        guard let index = userStates[user.id]?.presentedMovieResultIndex,
            let movie = userStates[user.id]?.movieResults?[index - 1] else { return }
        userStates[user.id]?.presentedMovieResultIndex = index - 1
        try showMessage(for: movie, for: user, in: message.chat)
    }
}
