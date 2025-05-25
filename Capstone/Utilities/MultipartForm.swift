//
//  MultipartForm.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-05-13.
//

//  A tiny, dependency‑free helper that assembles multipart/form‑data bodies.
//  Usage:
//
//  let multipart = try MultipartForm.Builder()
//      .append("My scan", named: "name")
//      .append(jpegDataArray, named: "files[]", mimeType: "image/jpeg")
//      .build()
//
//  var request = URLRequest(url: uploadURL)
//  request.httpMethod = "POST"
//  request.httpBody   = multipart.data
//  request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")
//

import Foundation

// MARK: - Public container returned by Builder.build()

public struct MultipartPayload {
    public let data: Data
    public let contentType: String   // "multipart/form‑data; boundary=..."
}

// MARK: - MultipartForm

public struct MultipartForm {
    fileprivate struct Part {
        let name: String
        let filename: String?
        let mimeType: String
        let data: Data
    }

    fileprivate let boundary: String
    fileprivate var parts: [Part] = []

    fileprivate mutating func append(_ part: Part) {
        parts.append(part)
    }

    // Serialise into Data + header value
    fileprivate func build() throws -> MultipartPayload {
        var body = Data()
        let lineBreak = "\r\n"

        for part in parts {
            body.append("--\(boundary)\r\n")
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let fn = part.filename {
                disposition += "; filename=\"\(fn)\""
            }
            body.append(disposition + lineBreak)
            body.append("Content-Type: \(part.mimeType)\r\n\r\n")
            body.append(part.data)
            body.append(lineBreak)
        }
        body.append("--\(boundary)--\r\n")

        let header = "multipart/form-data; boundary=\(boundary)"
        return MultipartPayload(data: body, contentType: header)
    }
}

// MARK: - Fluent Builder

public extension MultipartForm {

    final class Builder {
        private var form: MultipartForm

        public init(boundary: String = "Boundary-\(UUID().uuidString)") {
            self.form = MultipartForm(boundary: boundary)
        }

        // Append a simple text field
        @discardableResult
        public func append(_ value: String, named name: String, mimeType: String = "text/plain; charset=utf-8") -> Builder {
            guard let data = value.data(using: .utf8) else { return self }
            form.append(.init(name: name,
                              filename: nil,
                              mimeType: mimeType,
                              data: data))
            return self
        }

        // Append a single binary blob
        @discardableResult
        public func append(_ data: Data, named name: String, filename: String = "file", mimeType: String) -> Builder {
            form.append(.init(name: name,
                              filename: filename,
                              mimeType: mimeType,
                              data: data))
            return self
        }

        // Append multiple blobs (convenience)
        @discardableResult
        public func append(_ datas: [Data], named name: String, mimeType: String, filenamePrefix: String = "file", fileExtension: String? = nil) -> Builder {
            for (idx, data) in datas.enumerated() {
                let ext = fileExtension.map { ".\($0)" } ?? ""
                append(data,
                       named: name,
                       filename: "\(filenamePrefix)_\(idx)\(ext)",
                       mimeType: mimeType)
            }
            return self
        }

        // Final step – serialise everything
        public func build() throws -> MultipartPayload {
            try form.build()
        }
    }
}

// MARK: - Private Data helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
