import Foundation

/// `Endpoint` is an abstraction around making REST requests. It
/// includes a `Request` type, representing the data needed to
/// make the request, and a `Response` type, representing the
/// expected response from the server.
///
/// `Endpoint`s are defined via property wrapped (@GET, @POST, etc...)
/// properties on an `EndpointGroup`.
///
/// `Endpoint`s are intended to be used on either client or server for
/// requesting external endpoints or on server for providing and
/// validating endpoints. There are partner libraries
/// (`PapyrusAlamofire` and `Alchemy`) for requesting or
/// validating endpoints on client or server platforms.
public struct Endpoint<Request: EndpointRequest, Response: EndpointResponse> {
    public var baseURL: String = ""
    public var baseRequest = PartialRequest()
    public var baseResponse = PartialResponse()
    
    public mutating func setKeyMapping(_ keyMapping: KeyMapping) {
        baseRequest.keyMapping = keyMapping
        baseResponse.keyMapping = keyMapping
    }
    
    public mutating func setConverter(_ converter: ContentConverter) {
        baseRequest.contentConverter = converter
        baseResponse.contentConverter = converter
    }
    
    // MARK: Decoding
    
    public func decodeRequest(method: String, path: String, headers: [String: String], parameters: [String: String], query: String, body: Data?) throws -> Request {
        let raw = RawRequest(method: method, baseURL: "", path: path, headers: headers, parameters: parameters, query: query, body: body, queryConverter: baseRequest.queryConverter, contentConverter: baseRequest.contentConverter)
        return try Request(from: raw)
    }
    
    public func decodeResponse(headers: [String: String], body: Data?) throws -> Response {
        let raw = RawResponse(headers: headers, body: body, contentConverter: baseResponse.contentConverter)
        return try Response(from: raw)
    }
    
    // MARK: Encoding
    
    public func rawRequest(with request: Request) throws -> RawRequest {
        let properties: [(label: String, value: Any)] = Mirror(reflecting: request).children.compactMap {
            guard let label = $0.label else { return nil }
            return (label, $0.value)
        }
        
        let modifierProperties: [(String, RequestBuilder)] = properties.compactMap { child in
            guard let modifier = child.value as? RequestBuilder else { return nil }
            return (child.label, modifier)
        }
        
        let otherProperties: [(String, Any)] = properties.compactMap { child in
            guard !(child.value is RequestBuilder) else { return nil }
            return (child.label, child.value)
        }

        var result = baseRequest
        if !modifierProperties.isEmpty && otherProperties.isEmpty {
            for (label, property) in modifierProperties {
                // Remove _ from property wrappers.
                let cleanedLabel = String(label.dropFirst())
                property.build(components: &result, for: cleanedLabel)
            }
        } else if modifierProperties.isEmpty && !otherProperties.isEmpty {
            result.setBody(request)
        } else if !modifierProperties.isEmpty && !otherProperties.isEmpty {
            preconditionFailure("For now, can't have both `RequestModifers` and other properties on RequestConvertible type \(Request.self).")
        }
        
        return try result.create(baseURL: baseURL)
    }
    
    public func rawResponse(with response: Response) throws -> RawResponse {
        var components = baseResponse
        try components.setBody(value: response)
        return components.create()
    }
}

extension Endpoint where Request == Empty {
    func rawRequest() throws -> RawRequest {
        try baseRequest.create(baseURL: baseURL)
    }
}

extension Endpoint where Response == Empty {
    func rawResponse() -> RawResponse {
        baseResponse.create()
    }
}
