//
// Copyright (c) 2024 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Foundation

@_spi(AdyenInternal)
public protocol ImageLoading {
    @discardableResult
    func load(url: URL, completion: @escaping ((UIImage?) -> Void)) -> AdyenCancellable
}

@_spi(AdyenInternal)
public final class ImageLoader: ImageLoading {
    
    private let urlSession: URLSession
    
    public init(urlSession: URLSession = .init(configuration: .default)) {
        self.urlSession = urlSession
    }
    
    @discardableResult
    public func load(url: URL, completion: @escaping ((UIImage?) -> Void)) -> AdyenCancellable {
        var urlSessionTask: URLSessionTask?
        let cancellation = AdyenCancellation { urlSessionTask?.cancel() }
        
        urlSessionTask = urlSession.dataTask(with: url) { [weak self] data, _, _ in
            guard !cancellation.isCancelled else { return }
            self?.handleImageResponse(data: data, completion: completion)
        }
        
        urlSessionTask?.resume()
        
        return cancellation
    }
    
    private func handleImageResponse(data: Data?, completion: @escaping ((UIImage?) -> Void)) {
        guard let data, let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        DispatchQueue.main.async {
            completion(image)
        }
    }
}
