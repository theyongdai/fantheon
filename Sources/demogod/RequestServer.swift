//
//  RequestServer.swift
//  CHTTPParser
//
//

import Kitura
import Foundation
import HeliumLogger
import LoggerAPI

struct RequestServerDevConfig {
    var debugLevel: LoggerMessageType = .info
}

class RequestServer {
    
    fileprivate let router = Router()

    fileprivate let workQueue = DispatchQueue(label: "com.downloadthebear.requestServer.workq")
    fileprivate var config: RequestServerContext
    
    #if DEBUG
    fileprivate var devConfig = RequestServerDevConfig(debugLevel: .debug)
    #else
    fileprivate var devConfig = RequestServerDevConfig()
    #endif

    fileprivate func setupRoutes() {
        Log.info("Setup Routes")
        
        router.all { [weak self] (request, resp, next) in
            guard let strongSelf = self else { return }
            let config = strongSelf.config
            
            Log.info("Request \(request.urlURL.absoluteString)")
            let storePath = URL(fileURLWithPath: config.storeUrl.path)
            let fileNameLiteral = String.fileName(fromRequest: request)
            let profileName = config.profile
            let containedFolder = storePath
                .appendingPathComponent(profileName, isDirectory: true)

            let matches = FileManager.default
                .fileNames(at: containedFolder)
                .filter({ !$0.hasPrefix("_") })
                .filter({ fileNameLiteral.range(of: $0, options: .regularExpression) != nil })
            
            let fileName = matches.first ?? fileNameLiteral
            Log.info("Using first of \(matches.count): \(fileName)")
            
            let fileUrl = containedFolder
                .appendingPathComponent(fileName, isDirectory: false)

            let data = config.defaultJSONData
            resp.headers.setType(request.urlURL.pathExtension)
            
            if FileManager.default.isReadableFile(atPath: fileUrl.path) {
                let tags = FileManager.tags(forURL: fileUrl)
                let code: HTTPStatusCode = tags.first?.statusCode ?? .accepted
                Log.info("Using \(fileName): \(code.rawValue) \(code)")
                
                guard let file = try? Data(contentsOf: fileUrl) else {
                    try resp.send(data: data).status(code).end()
                    return
                }
                try resp.send(data: file).status(code).end()
                
            } else {
                if !FileManager.default.isReadableFile(atPath: containedFolder.path) {
                    try? FileManager.default.createDirectory(atPath: containedFolder.path,
                                                             withIntermediateDirectories: true,
                                                             attributes: nil)
                }
                try? data.write(to: fileUrl, options: .atomicWrite)
                try? resp.send(data: data).status(.created).end()
                
            }
            
            let metaFile = containedFolder
                .appendingPathComponent(String.metaFileName(fromRequest: request),
                                        isDirectory: false)
            if let metaData = RequestServer.processAndCreate(metafileFrom: request).data(using: .utf8) {
                try? metaData.append(fileURL: metaFile)
            }
        }
    }
    
    static fileprivate func processAndCreate(metafileFrom req: RouterRequest) -> String {
        let result =
"""
### Sample URL
`\(req.urlURL.absoluteString)`
### Sample Query
\(req.queryParameters.description)


"""
        return result
    }
    
    fileprivate func processAndApply(config cfg: RequestServerContext) {
        HeliumLogger.use(devConfig.debugLevel)
    }
    
    //MARK:- Public API
    //MARK:
    
    init(config: RequestServerContext = RequestServerContext()) {
        self.config = config
    }
    
    func update(config cfg: RequestServerContext) {
        self.workQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.config = cfg
            strongSelf.processAndApply(config: cfg)
        }
    }
    
    func requestServer(config cfgReq: @escaping ((RequestServerContext)->())) {
        self.workQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            cfgReq(strongSelf.config)
        }
    }

    func run(onPort port: Int) {
        self.workQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            HeliumLogger.use(strongSelf.devConfig.debugLevel)
            
            Log.info("starting the server on port \(port)")
            strongSelf.setupRoutes()
            Kitura.addHTTPServer(onPort: port, with: strongSelf.router)
            Kitura.start()
        }
    }
    
    func stop() {
        self.workQueue.async {
            Kitura.stop()
            Log.info("stopped the server")
        }
    }
    
}
