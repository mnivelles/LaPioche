import Vapor

struct GameSearchFilterDTO: Content {
    let q: String?
    let players: Int?
    let maxDuration: Int?
}

extension GameSearchFilterDTO: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("players", as: Int.self, is: .range(1...), required: false)
        validations.add("maxDuration", as: Int.self, is: .range(1...), required: false)
    }
}
