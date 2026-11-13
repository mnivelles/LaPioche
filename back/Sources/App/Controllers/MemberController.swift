import Fluent
import Vapor

struct MemberController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let members = routes.grouped("members")
        members.get(use: index)
        members.post(use: create)
        
        members.group(":memberID") { member in
            member.get(use: show)
            member.put(use: update)
            member.delete(use: delete)
            member.get("loans", use: listLoans)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [MemberDTO] {
        try await Member.query(on: req.db).all().map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        try MemberInputDTO.validate(content: req)
        let input = try req.content.decode(MemberInputDTO.self)

        let emailTaken = try await Member.query(on: req.db)
            .filter(\.$email == input.email)
            .count() > 0
        guard !emailTaken else {
            throw Abort(.conflict, reason: "A member with this email already exists")
        }

        let member = input.toModel()
        try await member.create(on: req.db)
        return try await member.toDTO().encodeResponse(status: .created, for: req)
    }

    @Sendable
    func show(req: Request) async throws -> MemberDTO {
        try await findMember(req: req).toDTO()
    }
    
    @Sendable
    func update(req: Request) async throws -> MemberDTO {
        try MemberInputDTO.validate(content: req)
        let input = try req.content.decode(MemberInputDTO.self)
        
        let member = try await findMember(req: req)
        
        let emailTaken = try await Member.query(on: req.db)
            .filter(\.$email == input.email)
            .count() > 0
        
        guard !emailTaken || member.email == input.email else {
            throw Abort(.conflict,
                        reason: "A member with this email already exists")
        }
        
        apply(input: input, to: member)
        try await member.update(on: req.db)
        
        return member.toDTO()
    }
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let member = try await findMember(req: req)
        
        try await member.$loans.load(on: req.db)
        
        guard member.loans.isEmpty else {
            throw Abort(.conflict,
                        reason: "A member with loans cannot be deleted")
        }
        
        try await member.delete(on: req.db)
        
        return .noContent
    }
    
    private func listLoans(req: Request) async throws -> [LoanDTO] {
        let member = try await findMember(req: req)
        
        try await member.$loans.load(on: req.db)
        
        return member.loans.map { $0.toDTO() }
    }
    
    private func findMember(req: Request) async throws -> Member {
        guard let memberID = req.parameters.get("memberID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid member id")
        }
        
        guard let member = try await Member.find(memberID, on: req.db) else {
            throw Abort(.notFound, reason: "Member not found")
        }
        
        return member
    }
    
    private func apply(input: MemberInputDTO, to member: Member) {
        member.name = input.name
        member.email = input.email
    }
}
