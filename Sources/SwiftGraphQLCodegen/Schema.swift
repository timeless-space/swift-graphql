import Foundation

public struct GraphQLSchema {
    /// Downloads a schema from the provided endpoint to the target file path.
    ///
    /// - Parameters:
    ///     - endpoint: The URL of your GraphQL server.
    ///     - handler: Introspection schema handler.
    public static func downloadFrom(_ endpoint: URL, handler: @escaping (GraphQL.Schema) -> Void) {
        self.downloadFrom(endpoint) { (data: Data) -> Void in handler(parse(data)) }
    }
    
    
    /// Downloads a schema from the provided endpoint to the target file path.
    ///
    /// - Parameters:
    ///     - endpoint: The URL of your GraphQL server.
    ///     - handler: Introspection schema handler.
    public static func downloadFrom(_ endpoint: URL, handler: @escaping (Data) -> Void) -> Void {        
        /* Compose a request. */
        var request = URLRequest(url: endpoint)
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        
        let query: [String: Any] = ["query": introspectionQuery]
        
        request.httpBody = try! JSONSerialization.data(
            withJSONObject: query,
            options: JSONSerialization.WritingOptions()
        )
        
        /* Load the schema. */
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            /* Check for errors. */
            if let _ = error {
                print("ERROR")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("BAD RES")
                return
            }
            
            /* Save JSON to file. */
            if let data = data {
                handler(data)
            }
        }
        
        task.resume()
    }

    public static let introspectionQuery: String = """
        query IntrospectionQuery($includeDeprecated: Boolean = true) {
          __schema {
            queryType {
              name
            }
            mutationType {
              name
            }
            subscriptionType {
              name
            }
            types {
              ...FullType
            }
          }
        }

        fragment FullType on __Type {
          kind
          name
          description
          fields(includeDeprecated: $includeDeprecated) {
            ...Field
          }
          inputFields {
            ...InputValue
          }
          interfaces {
            ...TypeRef
          }
          enumValues(includeDeprecated: $includeDeprecated) {
            ...EnumValue
          }
          possibleTypes {
            ...TypeRef
          }
        }

        fragment Field on __Field {
          name
          description
          args {
            ...InputValue
          }
          type {
            ...TypeRef
          }
          isDeprecated
          deprecationReason
        }

        fragment InputValue on __InputValue {
          name
          description
          type {
            ...TypeRef
          }
          defaultValue
        }

        fragment EnumValue on __EnumValue {
          name
          description
          isDeprecated
          deprecationReason
        }



        fragment TypeRef on __Type {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                    ofType {
                      kind
                      name
                      ofType {
                        kind
                        name
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """
    
    /// Decodes the received schema representation into Swift abstract type.
    static func parse(_ data: Data) -> GraphQL.Schema {
        let decoder = JSONDecoder()
        let result = try! decoder.decode(GraphQL.Reponse<GraphQL.IntrospectionQuery>.self, from: data)
        
        return result.data.schema
    }
}

/* Parser */

public enum GraphQL {
    /* General response format. */
    public struct Reponse<T: Decodable>: Decodable {
        public let data: T
    }
    
    /* Introspection query decoders. */
    
    public struct IntrospectionQuery: Decodable {
        public let schema: Schema
        
        enum CodingKeys: String, CodingKey {
            case schema = "__schema"
        }
    }
    
    /* Schema */
    
    public struct Schema: Decodable {
        public let types: [FullType]
        /* Root Types */
        public let queryType: Operation
        public let mutationType: Operation?
        public let subscriptionType: Operation?
        
        // MARK: - Calculated values
        
        public var objects: [FullType] {
            types.filter { $0.kind == .object && !$0.isBuiltIn }
        }
        
        public var enums: [FullType] {
            types.filter { $0.kind == .enumeration && !$0.isBuiltIn }
        }
    }
    
    public enum TypeKind: String, Codable {
        case scalar = "SCALAR"
        case object = "OBJECT"
        case interface = "INTERFACE"
        case union  = "UNION"
        case enumeration = "ENUM"
        case inputObject = "INPUT_OBJECT"
        case list = "LIST"
        case nonNull = "NON_NULL"
    }
    
    /* Types */
    
    public struct Operation: Codable {
        public let name: String
    }
    
    public struct FullType: Decodable {
        public let kind: TypeKind
        public let name: String
        public let description: String?
        /* Type properties */
        public let fields: [Field]?
        public let inputFields: [InputValue]?
        public let interfaces: [TypeRef]?
        public let enumValues: [EnumValue]?
        public let possibleTypes: [TypeRef]?
        
        // MARK: - Computed properties
        
        var isBuiltIn: Bool {
            name.starts(with: "__")
        }
    }
    
    /* Fields */
    
    public struct Field: Decodable {
        public let name: String
        public let description: String?
        public let args: [InputValue]
        public let type: TypeRef
        public let isDeprecated: Bool
        public let deprecationReason: String?
    }
    
    /// Represents a possibly wrapped type.
    public indirect enum TypeRef: Decodable {
        /* Types */
        case named(NamedType)
        /* Wrappers */
        case nonNull(TypeRef)
        case list(TypeRef)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let kind = try container.decode(TypeKind.self, forKey: .kind)
            
            switch kind {
            /* Wrappers */
            case .list:
                let ref = try container.decode(TypeRef.self, forKey: .ofType)
                self = .list(ref)
            case .nonNull:
                let ref = try container.decode(TypeRef.self, forKey: .ofType)
                self = .nonNull(ref)
            /* Named Types */
            case .scalar:
                let scalar = try container.decode(Scalar.self, forKey: .name)
                self = .named(.scalar(scalar))
            case .object:
                let name = try container.decode(String.self, forKey: .name)
                self = .named(.object(name))
            case .interface:
                let name = try container.decode(String.self, forKey: .name)
                self = .named(.interface(name))
            case .union:
                let name = try container.decode(String.self, forKey: .name)
                self = .named(.union(name))
            case .enumeration:
                let name = try container.decode(String.self, forKey: .name)
                self = .named(.enumeration(name))
            case .inputObject:
                let name = try container.decode(String.self, forKey: .name)
                self = .named(.inputObject(name))
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case kind = "kind"
            case name = "name"
            case ofType = "ofType"
        }
        
        // MARK: - Calculated properties
        
        var namedType: NamedType {
            switch self {
            case .named(let type):
                return type
            case .nonNull(let subRef), .list(let subRef):
                return subRef.namedType
            }
        }
    }
    
    /// Represents possible referable types.
    public enum NamedType {
        case scalar(Scalar)
        case object(String)
        case interface(String)
        case union(String)
        case enumeration(String)
        case inputObject(String)
    }
    
    public enum Scalar: Codable {
        case id
        case string
        case boolean
        case integer
        case float
        case custom(String)
        
        // MARK: - Initializer
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            let scalar = try container.decode(String.self)
            
            switch scalar {
            case "ID":
                self = .id
            case "String":
                self = .string
            case "Boolean":
                self = .boolean
            case "Int":
                self = .integer
            case "Float":
                self = .float
            default:
                self = .custom(scalar)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch self {
            case .id:
                try container.encode("ID")
            case .string:
                try container.encode("String")
            case .boolean:
                try container.encode("Boolean")
            case .integer:
                try container.encode("Int")
            case .float:
                try container.encode("Float")
            case .custom(let scalar):
                try container.encode(scalar)
            }
            
        }
    }
    
    /* Values */
    
    public struct InputValue: Decodable {
        public let name: String
        public let description: String?
        public let type: TypeRef
        public let defaultValue: String?
    }
    
    public struct EnumValue: Codable {
        public let name: String
        public let description: String?
        public let isDeprecated: Bool
        public let deprecationReason: String?
    }
}

