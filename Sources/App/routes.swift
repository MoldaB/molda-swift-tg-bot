import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get("/") { (request) -> String in
        return "Welcome To Moldas Bot"
    }
}
