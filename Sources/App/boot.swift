import Vapor
import Telegrammer

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    let botService = try app.make(SuggestionBot.self)
    
    /// Starting longpolling way to receive bot updates
    /// Or either use webhooks by calling `startWebhooks()` method instead
    _ = try botService.updater?.startLongpolling()
}
