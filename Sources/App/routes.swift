import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    
    // "It works" page
    router.get { req -> EventLoopFuture<View> in
        let test = req.query[String.self, at: "test"] ?? ""
        return try req.view()
            .render(
                "welcome",
                [
                    "test": test
                ]
            )
    }
    
    // Says hello
    router.get("hello", String.parameter) { req -> Future<View> in
        let test = req.query[String.self, at: "test"] ?? ""
        return try req.view()
            .render(
                "hello",
                [
                    "name": req.parameters.next(String.self),
                    "test": test
                ]
            )
    }
    
    // Crash
    router.get("crash", String.parameter) { req -> Future<View> in
        _ = try req.parameters.next(Int.self)
        return try req.view().render("welcome")
    }
}
