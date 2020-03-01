//
//  HTMLErrorMiddleware.swift
//  App
//
//  Created by Steven Grosmark on 3/1/20.
//

import Vapor

/// Captures all errors and transforms them into an internal server error HTTP response.
public final class HTMLErrorMiddleware: Middleware, Service {
    
    private let files: [File]
    private var publicDirectory: String!
    private var resourceDirectory: String!
    private var isRelease: Bool = true
    private var log: Logger!
    
    init(_ files: File...) {
        self.files = files.sorted { a, b -> Bool in
            a.range.upperBound > b.range.upperBound
        }
    }
    
    /// See `Middleware`.
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        let response: Future<Response>
        do {
            response = try next.respond(to: req)
        } catch {
            response = req.eventLoop.newFailedFuture(error: error)
        }
        
        return response.catchFlatMap { error in
            if let response = error as? ResponseEncodable {
                do {
                    return try response.encode(for: req)
                } catch {
                    return req.future(self.handleError(req, error))
                }
            } else {
                return req.future(self.handleError(req, error))
            }
        }
    }
    
    private func cache(with req: Request) throws {
        guard publicDirectory == nil else { return }
        publicDirectory = try req.sharedContainer.make(DirectoryConfig.self).workDir + "Public/"
        resourceDirectory = try req.sharedContainer.make(DirectoryConfig.self).workDir + "Resources/"
        isRelease = req.sharedContainer.environment.isRelease
        log = try req.sharedContainer.make(Logger.self)
    }
        
    private func handleError(_ req: Request, _ error: Error) -> Response {
        do {
            try cache(with: req)
        }
        catch {
            return req.response("\(error)")
        }
        
        // log the error
        log.report(
            error: error,
            request: req,
            verbose: !isRelease
        )
        
        // variables to determine
        let status: HTTPResponseStatus
        let reason: String
        let headers: HTTPHeaders
        
        // inspect the error type
        switch error {
            
        case let abort as AbortError:
            // this is an abort error, we should use its status, reason, and headers
            reason = abort.reason
            status = abort.status
            headers = abort.headers
            
        case let validation as ValidationError:
            // this is a validation error
            reason = validation.reason
            status = .badRequest
            headers = [:]
            
        case let debuggable as Debuggable where !isRelease:
            // if not release mode, and error is debuggable, provide debug
            // info directly to the developer
            reason = debuggable.reason
            status = .internalServerError
            headers = [:]
            
        default:
            // not an abort error, and not debuggable or in dev mode
            // just deliver a generic 500 to avoid exposing any sensitive error info
            reason = "Something went wrong."
            status = .internalServerError
            headers = [:]
        }
        
        // create a Response with appropriate status
        let res = req.response(http: .init(status: status, headers: headers))
        
        // attempt to serialize the error to html
        do {
            if let file = files.first(where: { $0.range ~= status.code }) {
                let filePath: String
                switch file.location {
                case .public(let filename): filePath = publicDirectory + filename
                case .resource(let filename): filePath = resourceDirectory + filename
                }
                
                // check if file exists and is not a directory
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue {
                    let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                    res.http.body = HTTPBody(data: data)
                    res.http.headers.replaceOrAdd(name: .contentType, value: "text/html; charset=utf-8")
                    return res
                }
            }
            
            res.http.body = HTTPBody(string: "\(status)\n\n\(reason)")
            res.http.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
        }
        catch {
            res.http.body = HTTPBody(string: "Oops: \(error)")
            res.http.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
        }
        return res
    }
    
    struct File {
        let location: Location
        let range: ClosedRange<UInt>
        
        enum Location {
            case `public`(String)
            case resource(String)
        }
        
        init(_ location: Location, _ range: ClosedRange<UInt>) {
            self.location = location
            self.range = range
        }
        
        static func `public`(file: String, for status: UInt) -> File {
            File(.public(file), status...status)
        }
        static func `public`(file: String, for status: PartialRangeFrom<UInt>) -> File {
            File(.public(file), status.lowerBound...599)
        }
        static func `public`(file: String, for status: PartialRangeThrough<UInt>) -> File {
            File(.public(file), 0...status.upperBound)
        }
        static func `public`(file: String, for status: PartialRangeUpTo<UInt>) -> File {
            File(.public(file), 0...(status.upperBound + 1))
        }
        
        static func resource(file: String, for status: UInt) -> File {
            File(.resource(file), status...status)
        }
        static func resource(file: String, for status: PartialRangeFrom<UInt>) -> File {
            File(.resource(file), status.lowerBound...599)
        }
        static func resource(file: String, for status: PartialRangeThrough<UInt>) -> File {
            File(.resource(file), 0...status.upperBound)
        }
        static func resource(file: String, for status: PartialRangeUpTo<UInt>) -> File {
            File(.resource(file), 0...(status.upperBound + 1))
        }
        
    }
    
}
