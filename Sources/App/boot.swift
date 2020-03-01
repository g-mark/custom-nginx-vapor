import Vapor

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    if app.environment == .production {
        FileManager.default.createFile(atPath: "/tmp/app-initialized", contents: Data())
    }
}
