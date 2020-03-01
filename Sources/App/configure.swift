import Leaf
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(LeafProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    // Use Leaf for rendering views
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    
    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    
    // Serve files from `Public/` directory:
    //middlewares.use(FileMiddleware.self)
    
    // Standard middleware, reports errors in JSON
    //middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    
    // Use a custom middleware so the same error files can be served by NGiNx and Vapor:
    middlewares.use(
        HTMLErrorMiddleware(
            .public(file: "404.html", for: 404),
            .resource(file: "5xx.html", for: 500...)
        )
    )
    
    services.register(middlewares)
}
