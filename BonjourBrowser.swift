//
//  BonjourBrowser.swift
//  NordicWiFiProvisioner-SoftAP
//
//  Created by Dinesh Harjani on 29/4/24.
//

import Foundation
import Network

// MARK: - BonjourBrowser

final public class BonjourBrowser {
    
    // MARK: Properties
    
    private var browser: NWBrowser?
    private lazy var cachedIPAddresses = [String: String]()
    
    public var delegate: ProvisionManager.Delegate?
    
    // MARK: Init
    
    public init() {}
    
    deinit {
        browser?.cancel()
        browser = nil
    }
    
    // MARK: API
    
    public func findBonjourService(type: String, domain: String, name: String) async throws -> BonjourService {
        // Wait a couple of seconds for the connection to settle-in.
        try? await Task.sleepFor(seconds: 2)
        
        if browser != nil {
            browser?.cancel()
            browser = nil
        }
        browser = NWBrowser(for: .bonjour(type: type, domain: domain),
                            using: .discoveryParameters)
        defer {
            delegate?.log("Cancelling Browser...", level: .debug)
            browser?.cancel()
        }
        return try await withCheckedThrowingContinuation { [weak browser] (continuation: CheckedContinuation<BonjourService, Error>) in
            browser?.stateUpdateHandler = { [delegate] newState in
                switch newState {
                case .setup:
                    delegate?.log("Setting up connection", level: .info)
                case .ready:
                    delegate?.log("Ready?", level: .info)
                case .failed(let error):
                    delegate?.log("\(error.localizedDescription)", level: .error)
                    continuation.resume(throwing: error)
                case .cancelled:
                    delegate?.log("Stopped / Cancelled", level: .info)
                case .waiting(let nwError):
                    delegate?.log("Waiting for \(nwError.localizedDescription)?", level: .info)
                default:
                    break
                }
            }
            
            browser?.browseResultsChangedHandler = { [delegate] results, changes in
                var netService: NetService?
                delegate?.log("Found \(results.count) results.", level: .debug)
                for result in results {
                    if case .service(let service) = result.endpoint, service.name == name {
                        netService = NetService(domain: service.domain, type: service.type, name: service.name)
                        break
                    }
                }
                
                guard let netService else { return }
                // Resolve IP Address here or else, if we do it later, it'll fail.
                BonjourResolver.resolve(service: netService) { [weak self] result in
                    switch result {
                    case .success(let ipAddress):
                        self?.cachedIPAddresses[netService.name] = ipAddress
                        self?.delegate?.log("Cached IP ADDRESS \(ipAddress) for Service \(netService.name)", level: .debug)
                        continuation.resume(returning: BonjourService(netService: netService))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 2.0))
            }
            delegate?.log("Starting Browser...", level: .debug)
            browser?.start(queue: .main)
        }
    }
    
    // MARK: IP Resolution
    
    public func resolveIPAddress(for service: BonjourService) async throws -> String {
        guard let cacheHit = cachedIPAddresses[service.name] else {
            delegate?.log("Cache Miss for Resolving \(service.name). Attempting to resolve again...",
                level: .fault)
            let resolvedIPAddress = try await BonjourResolver.resolve(service)
            return resolvedIPAddress
        }
        delegate?.log("Cache Hit for Resolving \(service.name)", level: .info)
        return cacheHit
    }
    
    public func clearCaches() {
        delegate?.log("Clearing Cached Resolved IP Addresses.",
            level: .debug)
        cachedIPAddresses.removeAll()
    }
}
