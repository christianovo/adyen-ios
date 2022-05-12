//
// Copyright (c) 2021 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Adyen
import AdyenNetworking
import Foundation

/// :nodoc:
internal protocol AnyAppleWalletPassProvider {
    /// :nodoc:
    typealias CompletionHandler = (Result<Data, Error>) -> Void

    /// :nodoc:
    func provide(with passToken: String, completion: @escaping CompletionHandler)
}

/// :nodoc:
internal final class AppleWalletPassProvider: AnyAppleWalletPassProvider,
    AdyenContextAware {
    
    /// :nodoc:
    internal let adyenContext: AdyenContext
    
    /// :nodoc:
    internal convenience init(adyenContext: AdyenContext) {
        self.init(adyenContext: adyenContext,
                  apiClient: nil)
    }
    
    /// :nodoc:
    internal init(adyenContext: AdyenContext, apiClient: AnyRetryAPIClient? = nil) {
        self.adyenContext = adyenContext
        if let apiClient = apiClient {
            self.retryApiClient = apiClient
        } else {
            let scheduler = SimpleScheduler(maximumCount: 2)
            self.retryApiClient = APIClient(apiContext: apiContext)
                .retryAPIClient(with: scheduler)
        }
    }

    /// :nodoc:
    internal func provide(with passToken: String, completion: @escaping CompletionHandler) {
        let request = AppleWalletPassRequest(passToken: passToken)
        apiClient.perform(request) { [weak self] result in
            self?.handle(result, completion: completion)
        }
    }
    
    // MARK: - Private
    
    /// :nodoc:
    private lazy var apiClient: UniqueAssetAPIClient<AppleWalletPassResponse> = {
        let retryOnErrorApiClient = retryApiClient.retryOnErrorAPIClient()
        return UniqueAssetAPIClient<AppleWalletPassResponse>(apiClient: retryOnErrorApiClient)
    }()

    /// :nodoc:
    private let retryApiClient: AnyRetryAPIClient

    /// :nodoc:
    private func handle(_ result: Result<AppleWalletPassResponse, Swift.Error>,
                        completion: @escaping CompletionHandler) {
        switch result {
        case let .success(response):
            completion(.success(response.passData))
        case let .failure(error):
            completion(.failure(error))
        }
    }
}
