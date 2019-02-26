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
    let omdbClient = OMDBService()
    
    ///Conformance to `ServiceType` protocol, fabric methhod
    static func makeService(for worker: Container) throws -> SuggestionBot {
        var token: String {
//            #if DEV
            return "732477711:AAHjjyRejej-u5cfbp_fk0rp153egMgLfjA"
//            #else
//            return "620164226:AAEonLqwAWZUVR3M44QsZJAXvd34XUJvbXc"
//            #endif
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
        guard let message = update.message else { return }
        try bot.sendMessage(params: .init(chatId: .chat(message.chat.id) , text: "מה קרה"))
    }
    
    /// handles suggestion command message for sending user in bot context
    ///
    /// - Parameters:
    ///   - message: sent by the user with the suggest command.
    ///   - user: sending party of the message
    ///   - context: BotContext or whatever
    /// - Throws: exeption if something else throws exception
    private func handleStartCommand(with message: Message, for user: User, in context: BotContext?) throws {
        try sendStartupMessage(in: .chat(message.chat.id))
    }
    

    /// Sends the message for all available commands
    ///
    /// - Parameter chatId: in chat
    /// - Throws: if message fails to be sent
    private func sendStartupMessage(in chatId: ChatId) throws {
        let params = Bot.SendMessageParams(chatId: chatId,
                                           text: """
                                            Try new commands
                                            /movie {movie name} for suggesting movies,
                                            /series for suggesting searies,
                                            /recipes for suggesting food,
                                            /music for suggesting a new song
                                            enjoy.
                                            """)
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
        omdbClient.searchMovie(name: movie) { response in
            switch response {
            case .failure(let error):
                if let error = error {
                    Logger.omdb.log(error: error, result: "", for: String(user.id))
                }
                break
            case .success(let movies):
                self.handleMovieResults(movies, for: user, in: message.chat)
            }
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
        userStates[user.id]?.location = [.movie]
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
    private func showMessage(for movie: MovieResult, after message: Message? = nil, for user: User, in chat: Chat) throws {
        // setup keys and keyboard markup
        let thisIsItButton = InlineKeyboardButton(text: "this is it".capitalized,
                                                  callbackData: "this_is_it_movie")
        let nextButton = InlineKeyboardButton(text: "next".capitalized,
                                              callbackData: "next_movie")
        let previousButton = InlineKeyboardButton(text: "previous".capitalized,
                                                  callbackData: "previous_movie")
        let cancelButton = InlineKeyboardButton(text: "cancel".capitalized,
                                                callbackData: "cancel")
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
        keys.append(cancelButton)
        let inlineMarkup = InlineKeyboardMarkup(inlineKeyboard: keys.map { [$0] })
        let keyboard = ReplyMarkup.inlineKeyboardMarkup(inlineMarkup)
        let messageText = ["Is this the movie you ment?","name - \(movie.name)","Year - \(movie.year)"].joined(separator: "\n")
        if let message = message { // edits previous message
            let media = InputMedia.inputMediaPhoto(.init(type: "photo", media: movie.poster, caption: messageText))
            let params = Bot.EditMessageMediaParams(chatId: .chat(message.chat.id),
                                                    messageId: message.messageId,
                                                    media: media,
                                                    replyMarkup: inlineMarkup)
            try bot.editMessageMedia(params: params)
        } else { // send new message
            userStates[user.id]?.location.following(.name)
            let photoParams = Bot.SendPhotoParams(chatId: .chat(chat.id),
                                                  photo: .url(movie.poster),
                                                  caption: messageText,
                                                  replyMarkup: keyboard)
            // send image
            try bot.sendPhoto(params: photoParams)
        }
    }
    
    private func sendNoMoviesFound(for user: User, in chat: Chat) throws {
        let messageParams = Bot.SendMessageParams(chatId: .chat(chat.id), text: "No Movies by that name was found, try again.")
        try bot.sendMessage(params: messageParams)
    }
    
    // MARK: CallbackQueryHandlers
    private func setupMovieCallbacksHandler() {
        let movieCallbackQueryHandler = CallbackQueryHandler(pattern: ".+_movie", callback: handleMovieQueryUpdate)
        dispatcher?.add(handler: movieCallbackQueryHandler)
        
//        let rateCallbackQueryHandler = CallbackQueryHandler(pattern: "^rate:\\d", callback: handleRatePickedQueryUpdate)
//        dispatcher?.add(handler: rateCallbackQueryHandler)
        
        let cancelCallbackQueryHandler = CallbackQueryHandler(pattern: "cancel", callback: handleCancelQueryUpdate)
        dispatcher?.add(handler: cancelCallbackQueryHandler)
    }
    
    enum MovieQueryKeys
    {
        case thisIsIt
        case next
        case previous
        case rate
        case suggest
        
        init?(rawValue: String) {
            guard !rawValue.contains("rate") else {
                self = .rate
                return
            }
            switch rawValue {
            case "this_is_it": self = .thisIsIt
            case "next": self = .next
            case "previous": self = .previous
            case "suggest": self = .suggest
            default:
                return nil
            }
        }
    }
    
    enum MovieError: Swift.Error
    {
        case invalidDataQuery
    }
    
    private func handleCancelQueryUpdate(_ update: Update, in context: BotContext?) throws {
        guard
            let message = update.callbackQuery?.message,
            let user = message.from else {
            throw MovieError.invalidDataQuery
        }
        userStates.removeValue(forKey: user.id)
        let params = Bot.DeleteMessageParams(chatId: .chat(message.chat.id), messageId: message.messageId)
        try bot.deleteMessage(params: params)
        try sendStartupMessage(in: .chat(message.chat.id))
    }
    
    // MARK: Movie Queries
    private func handleMovieQueryUpdate(_ update: Update, in context: BotContext?) throws {
        guard
            let clearData = update.callbackQuery?.data?.replacingOccurrences(of: "_movie", with: ""),
            let key = MovieQueryKeys(rawValue: clearData) else {
                throw MovieError.invalidDataQuery
        }
        switch key {
        case .next:
            try handleNextItQueryUpdate(update)
        case .previous:
            try handlePreviousQueryUpdate(update)
        case .thisIsIt:
            try handleThisIsItQueryUpdate(update)
        case .rate:
            try handleRatePickedQueryUpdate(update)
        case .suggest:
            try handleSuggestionUpdate(update)
        }
    }
    
    private func handleThisIsItQueryUpdate(_ update: Update) throws {
        guard
            let message = update.callbackQuery?.message,
            let user = update.callbackQuery?.from,
            let movie = userStates[user.id]?.presentedMovie else { return }
        userStates[user.id]?.location.following(.rate)
        
        omdbClient.getInformation(for: movie.id) { response in
            switch response {
            case .failure(let error):
                if let error = error {
                Logger.omdb.log(error: error, result: "failed to get movie info", for: String(user.id))
                }
                break
            case .success(let info):
                self.userStates[user.id]?.pickedMovie = info
                do {
                    try self.showRatingMessage(replacing: message)
                } catch {
                    Logger.general.log(error: error, result: "failed to show rating message", for: String(user.id))
                }
                break
            }
        }
    }
    
    private func handleNextItQueryUpdate(_ update: Update) throws {
        guard let message = update.callbackQuery?.message,
            let user = update.callbackQuery?.from else { return }
        // get next presented movie
        guard let index = userStates[user.id]?.presentedMovieResultIndex,
            let movie = userStates[user.id]?.movieResults?[index + 1] else { return }
        userStates[user.id]?.presentedMovieResultIndex = index + 1
        try showMessage(for: movie, after: message, for: user, in: message.chat)
    }
    
    private func handlePreviousQueryUpdate(_ update: Update) throws {
        guard let message = update.callbackQuery?.message,
            let user = update.callbackQuery?.from else { return }
        // get next presented movie
        guard let index = userStates[user.id]?.presentedMovieResultIndex,
            let movie = userStates[user.id]?.movieResults?[index - 1] else { return }
        userStates[user.id]?.presentedMovieResultIndex = index - 1
        try showMessage(for: movie, after: message, for: user, in: message.chat)
    }
    
    // MARK: Rate Query
    private func showRatingMessage(replacing message: Message) throws {
        // show rating
        let maxStars = 5
        let starsCount = Array(0...maxStars)
        var keys = starsCount.map { count -> InlineKeyboardButton in
            let starsString = (Array(repeating: "\u{2605}", count: count) + Array(repeating: "\u{2606}", count: maxStars - count)).joined()
            return InlineKeyboardButton(text: starsString,
                                        callbackData: "rate:\(count)_movie")
        }
        keys.append(InlineKeyboardButton(text: "cancel".capitalized, callbackData: "cancel".capitalized))
        let params = Bot.EditMessageReplyMarkupParams(chatId: .chat(message.chat.id),
                                                      messageId: message.messageId,
                                                      replyMarkup: .init(inlineKeyboard: keys.map { [$0] }))
        try bot.editMessageReplyMarkup(params: params)
    }
    private func handleRatePickedQueryUpdate(_ update: Update) throws {
        guard
            let message = update.callbackQuery?.message,
            let user = update.callbackQuery?.from,
            let ratingString = update.callbackQuery?.data?.replacingOccurrences(of: "_movie", with: "").split(separator: ":").last,
            let rate = Int(ratingString) else { return }
        userStates[user.id]?.pickedRating = rate // save rate
        
        try showFinalizedSuggestion(replacing: message, for: user, in: .chat(message.chat.id))
    }
    
    // MARK: Description Query
    private func showFinalizedSuggestion(replacing message: Message, for user: User, in chatId: ChatId) throws {
        guard
            let rating = userStates[user.id]?.pickedRating,
            let movie = userStates[user.id]?.pickedMovie else { return }
        
        let text = """
        \(movie.description)
        rate: \((Array(repeating: "\u{2605}", count: rating) + Array(repeating: "\u{2606}", count: 5 - rating)).joined())
        """
        let markup = InlineKeyboardMarkup(inlineKeyboard: [[InlineKeyboardButton.init(text: "Suggest", callbackData: "suggest_movie")],
                                                           [InlineKeyboardButton(text: "cancel".capitalized, callbackData: "cancel")]])
        let media = InputMedia.inputMediaPhoto(.init(type: "photo", media: movie.poster, caption: text))
        let params = Bot.EditMessageMediaParams(chatId: chatId,
                                                messageId: message.messageId,
                                                media: media,
                                                replyMarkup: markup)
        try bot.editMessageMedia(params: params)
    }
    
    private func handleSuggestionUpdate(_ update: Update) throws {
        guard
            let message = update.callbackQuery?.message,
            let user = update.callbackQuery?.from,
            let rating = userStates[user.id]?.pickedRating,
            let movie = userStates[user.id]?.pickedMovie else { return }
        
        let text = """
        \(movie.description)
        rate: \((Array(repeating: "\u{2605}", count: rating) + Array(repeating: "\u{2606}", count: 5 - rating)).joined())
        
        suggester: @\(user.username ?? "")
        """
        let photoParams = Bot.SendPhotoParams(chatId: .chat(-1001254557120),
                                              photo: .url(movie.poster),
                                              caption: text)
        try bot.sendPhoto(params: photoParams)
        try bot.editMessageMedia(params: .init(chatId: .chat(message.chat.id),
                                               messageId: message.messageId,
                                               media: InputMedia.inputMediaPhoto(.init(type: "photo",
                                                                                       media: movie.poster,
                                                                                       caption: "movie suggested!".capitalized))))
        userStates[user.id] = UserState(id: user.id, chatId: message.chat.id)
        try sendStartupMessage(in: .chat(message.chat.id))
    }
}
