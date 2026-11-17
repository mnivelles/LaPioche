import Vapor

struct GameSearchFilterDTO: Content {
    let q: String?
    let players: Int?
    let maxDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case q
        case players
        case maxDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        q = try container.decodeIfPresent(String.self, forKey: .q)
        players = try Self.positiveInt(container, .players)
        maxDuration = try Self.positiveInt(container, .maxDuration)
    }
    
    private static func positiveInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) throws -> Int? {
        guard let raw = try container.decodeIfPresent(String.self, forKey: key)?.trimmed,
              !raw.isEmpty else {
            return nil
        }
        
        guard let value = Int(raw), value >= 1 else {
            throw DecodingError.dataCorruptedError(forKey: key,
                                                   in: container,
                                                   debugDescription: "\(key.stringValue) must be an integer >= 1")
        }
        
        return value
    }
}
