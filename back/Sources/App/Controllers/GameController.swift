import Fluent
import Vapor

struct GameController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let games = routes.grouped("games")
        games.get(use: index)
        games.post(use: create)
        
        games.group(":gameID") { game in
            game.get(use: show)
            game.put(use: update)
            game.delete(use: delete)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [GameDTO] {
        let query = Game.query(on: req.db)
            .with(\.$loans)
        
        let input = try req.query.decode(GameSearchFilterDTO.self)
        
        if let searchText = input.q?.trimmed,
           !searchText.isEmpty {
            query
                .filter(\.$title ~~ searchText)
        }
        
        if let players = input.players {
            query
                .filter(\.$minPlayers <= players)
                .filter(\.$maxPlayers >= players)
        }
        
        if let maxDuration = input.maxDuration {
            query
                .filter(\.$durationMinutes <= maxDuration)
        }
        
        let games = try await query.all()
        
        return games.map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        try GameInputDTO.validate(content: req)
        let input = try req.content.decode(GameInputDTO.self)
        try input.ensureConsistentPlayerCount()

        let game = input.toModel()
        try await game.create(on: req.db)
        
        return try await game.toDTO().encodeResponse(status: .created, for: req)
    }

    @Sendable
    func show(req: Request) async throws -> GameDTO {
        try await findGame(req: req).toDTO()
    }
    
    @Sendable
    func update(req: Request) async throws -> GameDTO {
        try GameInputDTO.validate(content: req)
        let input = try req.content.decode(GameInputDTO.self)
        try input.ensureConsistentPlayerCount()
        
        let game = try await findGame(req: req)
        apply(input: input, to: game)
        try await game.update(on: req.db)
        
        return game.toDTO()
    }
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let game = try await findGame(req: req)
        
        try await game.$loans.load(on: req.db)
        
        guard game.loans.isEmpty else {
            throw Abort(.conflict,
                        reason: "A game with loans cannot be deleted")
        }
        
        try await game.delete(on: req.db)
        
        return .noContent
    }

    private func findGame(req: Request) async throws -> Game {
        guard let gameID = req.parameters.get("gameID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid game id")
        }
        guard let game = try await Game.query(on: req.db)
            .filter(\.$id == gameID)
            .with(\.$loans)
            .first()
        else {
            throw Abort(.notFound, reason: "Game not found")
        }
        return game
    }
    
    private func apply(input: GameInputDTO, to game: Game) {
        game.title = input.title
        game.minPlayers = input.minPlayers
        game.maxPlayers = input.maxPlayers
        game.durationMinutes = input.durationMinutes
    }
}
