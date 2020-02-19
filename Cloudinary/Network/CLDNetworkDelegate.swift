//
//  CLDNetworkDelegate.swift
//
//  Copyright (c) 2016 Cloudinary (http://cloudinary.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import Alamofire


internal class CLDNetworkDelegate: NSObject, CLDNetworkAdapter {
   
    init(configuration: URLSessionConfiguration? = nil) {
        if let configuration = configuration {
            manager = Session(configuration: configuration, startRequestsImmediately: false)
        } else {
            manager = Session(configuration: URLSessionConfiguration.af.default, startRequestsImmediately: false)
        }
    }

    private struct SessionProperties {
        static let identifier: String = Bundle.main.bundleIdentifier ?? "" + ".cloudinarySDKbackgroundSession"
    }

    fileprivate var manager: Session

    fileprivate let downloadQueue: OperationQueue = OperationQueue()

    internal static let sharedNetworkDelegate = CLDNetworkDelegate()

    // MARK: Features

    internal func cloudinaryRequest(_ url: String, headers: [String: String], parameters: [String: Any]) -> CLDNetworkDataRequest {
        
        let req: DataRequest = manager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: HTTPHeaders(headers))
        
        req.resume()
        return CLDNetworkDataRequestImpl(request: req)
    }

    internal func uploadToCloudinary(_ url: String, headers: [String: String], parameters: [String: Any], data: Any) -> CLDNetworkDataRequest {

        let asyncUploadRequest = CLDAsyncNetworkUploadRequest()
        
        let aa: (MultipartFormData) -> Void = { multipartFormData in

            if let data = data as? Data {
                multipartFormData.append(data, withName: "file", fileName: "file", mimeType: "application/octet-stream")
            } else if let url = data as? URL {
                if url.absoluteString.cldIsRemoteUrl() {
                    if let urlAsData = url.absoluteString.data(using: String.Encoding.utf8) {
                        multipartFormData.append(urlAsData, withName: "file")
                    }
                } else {
                    multipartFormData.append(url, withName: "file", fileName: url.lastPathComponent, mimeType: "application/octet-stream")
                }
            }

            for key in parameters.keys {
                if let value = parameters[key], value is [String] {
                    if let valueArr = value as? [String] {
                        for paramValue in valueArr {
                            if let valueData = paramValue.data(using: String.Encoding.utf8) {
                                multipartFormData.append(valueData, withName: key + "[]")
                            }
                        }
                    }
                } else if let value = parameters[key] as? String {
                    if value.isEmpty {
                        continue
                    }

                    if let valueData = value.data(using: String.Encoding.utf8) {
                        multipartFormData.append(valueData, withName: key)
                    }
                } else if let value = parameters[key] as? Bool {
                    if let valueData = String(describing: NSNumber(value: value)).data(using: String.Encoding.utf8) {
                        multipartFormData.append(valueData, withName: key)
                    }
                }
            }

        }
        
        asyncUploadRequest.networkDataRequest = CLDNetworkUploadRequest(request:
            manager.upload(multipartFormData: aa, to: url, usingThreshold: UInt64(), method: .post, headers: HTTPHeaders(headers))
        )
        
        return asyncUploadRequest
    }

    internal func downloadFromCloudinary(_ url: String) -> CLDFetchImageRequest {
        let req = manager.request(url)
        downloadQueue.addOperation { () -> () in
            req.resume()
        }
        return CLDNetworkDownloadRequest(request: req)
    }

    internal func setMaxConcurrentDownloads(_ maxConcurrentDownloads: Int) {
        downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads
    }
}
