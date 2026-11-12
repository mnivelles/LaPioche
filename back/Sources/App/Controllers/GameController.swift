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
        let games = try await Game.query(on: req.db)
            .with(\.$loans)
            .all()
        return games.map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        try GameInputDTO.validate(content: req)
        let dto = try req.content.decode(GameInputDTO.self)
        try dto.ensureConsistentPlayerCount()

        let game = dto.toModel()
        try await game.save(on: req.db)
        return try await game.toDTO().encodeResponse(status: .created, for: req)
    }

    @Sendable
    func show(req: Request) async throws -> GameDTO {
        try await findGame(req).toDTO()
    }
    
    @Sendable
    func update(req: Request) async throws -> GameDTO {
        try GameInputDTO.validate(content: req)
        let input = try req.content.decode(GameInputDTO.self)
        try input.ensureConsistentPlayerCount()
        
        let game = try await findGame(req)
        apply(input: input, to: game)
        try await game.update(on: req.db)
        
        return game.toDTO()
    }
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let game = try await findGame(req)
        
        try await game.$loans.load(on: req.db)
        
        guard game.loans.isEmpty else {
            throw Abort(.conflict, reason: "Game not found")
        }
        
        try await game.delete(on: req.db)
        
        return .noContent
    }

    private func findGame(_ req: Request) async throws -> Game {
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
