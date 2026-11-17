@testable import App
import XCTVapor

final class GameTests: XCTestCase {
    func testCreateGameReturnsCreated() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(GameInputDTO(
                    title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                let game = try res.content.decode(GameDTO.self)
                XCTAssertEqual(game.title, "Catan")
                XCTAssertTrue(game.isAvailable)
            })
        }
    }

    func testCreateGameWithEmptyTitleIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(GameInputDTO(
                    title: "", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testCreateGameWithInvertedPlayerBoundsIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(GameInputDTO(
                    title: "Catan", minPlayers: 5, maxPlayers: 2, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testCreateGameWithInvalidMinPlayersIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(GameInputDTO(
                    title: "Catan",
                    minPlayers: 0,
                    maxPlayers: 4,
                    durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testCreateGameWithInvalidMaxPlayersIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(GameInputDTO(
                    title: "Catan",
                    minPlayers: 1,
                    maxPlayers: 0,
                    durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testCreateGameWithInvalidDurationMinutesIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(GameInputDTO(
                    title: "Catan",
                    minPlayers: 2,
                    maxPlayers: 4,
                    durationMinutes: 0
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testListGames() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan")
            _ = try await createGame(app, title: "Dixit")
            _ = try await createGame(app, title: "Modit")
            _ = try await createGame(app, title: "Luxuous")
            _ = try await createGame(app, title: "Clarem")

            try await app.test(.GET, "games", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 5)
            })
        }
    }
    
    func testListGamesSearchingText() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan")
            _ = try await createGame(app, title: "Dixit")
            _ = try await createGame(app, title: "Modit")
            _ = try await createGame(app, title: "Luxuous")
            _ = try await createGame(app, title: "Clarem")
            
            try await app.test(.GET, "games?q=it", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 2)
            })
        }
    }
    
    func testListGamesSearchingWithPlayers() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan", minPlayers: 2, maxPlayers: 8)
            _ = try await createGame(app, title: "Dixit", minPlayers: 2, maxPlayers: 2)
            _ = try await createGame(app, title: "Modit", minPlayers: 4, maxPlayers: 6)
            _ = try await createGame(app, title: "Luxuous", minPlayers: 5, maxPlayers: 10)
            _ = try await createGame(app, title: "Clarem", minPlayers: 8, maxPlayers: 18)
            
            try await app.test(.GET, "games?players=6", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 3)
            })
        }
    }
    
    func testListGamesSearchingWithInvalidPlayers() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan", minPlayers: 2, maxPlayers: 8)
            _ = try await createGame(app, title: "Dixit", minPlayers: 2, maxPlayers: 2)
            _ = try await createGame(app, title: "Modit", minPlayers: 4, maxPlayers: 6)
            _ = try await createGame(app, title: "Luxuous", minPlayers: 5, maxPlayers: 10)
            _ = try await createGame(app, title: "Clarem", minPlayers: 8, maxPlayers: 18)
            
            try await app.test(.GET, "games?players=0", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testListGamesSearchingWithMaxDuration() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan", durationMinutes: 20)
            _ = try await createGame(app, title: "Dixit", durationMinutes: 60)
            _ = try await createGame(app, title: "Modit", durationMinutes: 45)
            _ = try await createGame(app, title: "Luxuous", durationMinutes: 30)
            _ = try await createGame(app, title: "Clarem", durationMinutes: 90)
            
            try await app.test(.GET, "games?maxDuration=45", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 3)
            })
        }
    }
    
    func testListGamesSearchingWithInvalidMaxDuration() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan", durationMinutes: 20)
            _ = try await createGame(app, title: "Dixit", durationMinutes: 60)
            _ = try await createGame(app, title: "Modit", durationMinutes: 45)
            _ = try await createGame(app, title: "Luxuous", durationMinutes: 30)
            _ = try await createGame(app, title: "Clarem", durationMinutes: 90)
            
            try await app.test(.GET, "games?maxDuration=0", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testListGamesSearchingWithAllParams() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan", minPlayers: 2, maxPlayers: 10, durationMinutes: 30)
            _ = try await createGame(app, title: "Dixit", minPlayers: 3, maxPlayers: 8, durationMinutes: 40)
            _ = try await createGame(app, title: "Modit", minPlayers: 4, maxPlayers: 8, durationMinutes: 60)
            _ = try await createGame(app, title: "Luxuous", minPlayers: 4, maxPlayers: 10, durationMinutes: 20)
            _ = try await createGame(app, title: "Clarem", minPlayers: 3, maxPlayers: 7, durationMinutes: 90)
            _ = try await createGame(app, title: "Partem", minPlayers: 2, maxPlayers: 2, durationMinutes: 25)
            _ = try await createGame(app, title: "Anamor", minPlayers: 4, maxPlayers: 12, durationMinutes: 90)
            
            try await app.test(.GET, "games?q=t&players=3&maxDuration=40", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 2)
            })
        }
    }
    
    func testListGamesAvailable() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            
            _ = try await createGame(app, title: "Catan", minPlayers: 2, maxPlayers: 10, durationMinutes: 30)
            _ = try await createGame(app, title: "Dixit", minPlayers: 3, maxPlayers: 8, durationMinutes: 40)
            let gameA = try await createGame(app, title: "Modit", minPlayers: 4, maxPlayers: 8, durationMinutes: 60)
            _ = try await createGame(app, title: "Luxuous", minPlayers: 4, maxPlayers: 10, durationMinutes: 20)
            _ = try await createGame(app, title: "Clarem", minPlayers: 3, maxPlayers: 7, durationMinutes: 90)
            let gameB = try await createGame(app, title: "Partem", minPlayers: 2, maxPlayers: 2, durationMinutes: 25)
            let gameC = try await createGame(app, title: "Anamor", minPlayers: 4, maxPlayers: 12, durationMinutes: 90)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameA.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameB.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameC.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture,
                                 returnedAt: .now)
            
            try await app.test(.GET, "games?available=true", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 5)
            })
        }
    }

    func testListGamesNotAvailable() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            
            _ = try await createGame(app, title: "Catan", minPlayers: 2, maxPlayers: 10, durationMinutes: 30)
            _ = try await createGame(app, title: "Dixit", minPlayers: 3, maxPlayers: 8, durationMinutes: 40)
            let gameA = try await createGame(app, title: "Modit", minPlayers: 4, maxPlayers: 8, durationMinutes: 60)
            _ = try await createGame(app, title: "Luxuous", minPlayers: 4, maxPlayers: 10, durationMinutes: 20)
            _ = try await createGame(app, title: "Clarem", minPlayers: 3, maxPlayers: 7, durationMinutes: 90)
            let gameB = try await createGame(app, title: "Partem", minPlayers: 2, maxPlayers: 2, durationMinutes: 25)
            let gameC = try await createGame(app, title: "Anamor", minPlayers: 4, maxPlayers: 12, durationMinutes: 90)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameA.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameB.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameC.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture,
                                 returnedAt: .now)
            
            try await app.test(.GET, "games?available=false", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 2)
            })
        }
    }
    
    func testListGamesWithInvalidAvailable() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            
            _ = try await createGame(app, title: "Catan", minPlayers: 2, maxPlayers: 10, durationMinutes: 30)
            _ = try await createGame(app, title: "Dixit", minPlayers: 3, maxPlayers: 8, durationMinutes: 40)
            let gameA = try await createGame(app, title: "Modit", minPlayers: 4, maxPlayers: 8, durationMinutes: 60)
            _ = try await createGame(app, title: "Luxuous", minPlayers: 4, maxPlayers: 10, durationMinutes: 20)
            _ = try await createGame(app, title: "Clarem", minPlayers: 3, maxPlayers: 7, durationMinutes: 90)
            let gameB = try await createGame(app, title: "Partem", minPlayers: 2, maxPlayers: 2, durationMinutes: 25)
            let gameC = try await createGame(app, title: "Anamor", minPlayers: 4, maxPlayers: 12, durationMinutes: 90)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameA.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameB.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameC.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture,
                                 returnedAt: .now)
            
            try await app.test(.GET, "games?available=17b", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testListGamesWithAvailableAndSearchParams() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            
            _ = try await createGame(app, title: "Catan", minPlayers: 2, maxPlayers: 10, durationMinutes: 30)
            _ = try await createGame(app, title: "Dixit", minPlayers: 3, maxPlayers: 8, durationMinutes: 40)
            let gameA = try await createGame(app, title: "Modit", minPlayers: 4, maxPlayers: 8, durationMinutes: 60)
            _ = try await createGame(app, title: "Luxuous", minPlayers: 4, maxPlayers: 10, durationMinutes: 20)
            _ = try await createGame(app, title: "Clarem", minPlayers: 3, maxPlayers: 7, durationMinutes: 90)
            let gameB = try await createGame(app, title: "Partem", minPlayers: 2, maxPlayers: 2, durationMinutes: 25)
            let gameC = try await createGame(app, title: "Anamor", minPlayers: 4, maxPlayers: 12, durationMinutes: 90)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameA.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameB.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture)
            
            try await insertLoan(app,
                                 gameID: try XCTUnwrap(gameC.id),
                                 memberID: try XCTUnwrap(member.id),
                                 borrowedAt: .distantPast,
                                 dueAt: .distantFuture,
                                 returnedAt: .now)
            
            try await app.test(.GET, "games?q=t&players=2&maxDuration=40&available=true", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                
                let output = try res.content.decode([GameDTO].self)
                
                XCTAssertEqual(output.count, 1)
                XCTAssertEqual(output.first?.title, "Catan")
            })
        }
    }
    
    func testShowGame() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)

            try await app.test(.GET, "games/\(id)", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode(GameDTO.self).id, id)
                XCTAssertEqual(try res.content.decode(GameDTO.self).title, game.title)
                XCTAssertEqual(try res.content.decode(GameDTO.self).minPlayers, game.minPlayers)
                XCTAssertEqual(try res.content.decode(GameDTO.self).maxPlayers, game.maxPlayers)
                XCTAssertEqual(try res.content.decode(GameDTO.self).durationMinutes, game.durationMinutes)
            })
        }
    }

    func testShowUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/\(UUID())", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }

    func testShowGameWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/not-a-uuid", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateGameReturnsOk() async throws {
        try await withApp { app in
            let testGame = try await createGame(app, title: "Quasi Veniam")
            let testGameID = try XCTUnwrap(testGame.id)
            
            let input = GameInputDTO(
                title: "Reprehenderit Et Quis",
                minPlayers: 2,
                maxPlayers: 8,
                durationMinutes: 60
            )
            
            try await app.test(.PUT, "games/\(testGameID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                
                let output = try res.content.decode(GameDTO.self)
                
                XCTAssertEqual(output.title, input.title)
                XCTAssertEqual(output.minPlayers, input.minPlayers)
                XCTAssertEqual(output.maxPlayers, input.maxPlayers)
                XCTAssertEqual(output.durationMinutes, input.durationMinutes)
            }
        }
    }
    
    func testUpdateGameWithEmptyTitleIsRejected() async throws {
        try await withApp { app in
            let testGame = try await createGame(app, title: "Quasi Veniam")
            let testGameID = try XCTUnwrap(testGame.id)
            
            let input = GameInputDTO(
                title: "",
                minPlayers: 2,
                maxPlayers: 8,
                durationMinutes: 60
            )
            
            try await app.test(.PUT, "games/\(testGameID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testUpdateGameWithInvertedPlayerBoundsIsRejected() async throws {
        try await withApp { app in
            let testGame = try await createGame(app, title: "Quasi Veniam")
            let testGameID = try XCTUnwrap(testGame.id)
            
            let input = GameInputDTO(
                title: "Reprehenderit Et Quis",
                minPlayers: 4,
                maxPlayers: 2,
                durationMinutes: 60
            )
            
            try await app.test(.PUT, "games/\(testGameID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testUpdateGameWithInvalidMinPlayersIsRejected() async throws {
        try await withApp { app in
            let testGame = try await createGame(app, title: "Quasi Veniam")
            let testGameID = try XCTUnwrap(testGame.id)
            
            let input = GameInputDTO(
                title: "Reprehenderit Et Quis",
                minPlayers: 0,
                maxPlayers: 4,
                durationMinutes: 60
            )
            
            try await app.test(.PUT, "games/\(testGameID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testUpdateGameWithInvalidMaxPlayersIsRejected() async throws {
        try await withApp { app in
            let testGame = try await createGame(app, title: "Quasi Veniam")
            let testGameID = try XCTUnwrap(testGame.id)
            
            let input = GameInputDTO(
                title: "Reprehenderit Et Quis",
                minPlayers: 1,
                maxPlayers: 0,
                durationMinutes: 60
            )
            
            try await app.test(.PUT, "games/\(testGameID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testUpdateGameWithInvalidDurationMinutesIsRejected() async throws {
        try await withApp { app in
            let testGame = try await createGame(app, title: "Quasi Veniam")
            let testGameID = try XCTUnwrap(testGame.id)
            
            let input = GameInputDTO(
                title: "Reprehenderit Et Quis",
                minPlayers: 2,
                maxPlayers: 4,
                durationMinutes: 0
            )
            
            try await app.test(.PUT, "games/\(testGameID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testUpdateUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            let input = GameInputDTO(
                title: "Reprehenderit Et Quis",
                minPlayers: 2,
                maxPlayers: 8,
                durationMinutes: 60
            )
            
            try await app.test(.PUT, "games/\(UUID())") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            }
        }
    }
    
    func testUpdateGameWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            let input = GameInputDTO(
                title: "Reprehenderit Et Quis",
                minPlayers: 2,
                maxPlayers: 8,
                durationMinutes: 60
            )
            
            try await app.test(.PUT, "games/not-a-uuid") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testDeleteGameReturnsNoContent() async throws {
        try await withApp { app in
            let testGame = try await createGame(app)
            let testGameID = try XCTUnwrap(testGame.id)
            
            try await app.test(.DELETE, "games/\(testGameID)",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .noContent)
            })
            
            let found = try await Game.find(testGameID,
                                            on: app.db)
            
            XCTAssertNil(found)
        }
    }
    
    func testDeleteGameUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.DELETE, "games/\(UUID())",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testDeleteGameWithLoansReturnsConflict() async throws {
        try await withApp { app in
            let testMember = try await createMember(app)
            let testMemberID = try XCTUnwrap(testMember.id)
            
            let testGame = try await createGame(app)
            let testGameID = try XCTUnwrap(testGame.id)
            
            try await insertLoan(
                app,
                gameID: testGameID,
                memberID: testMemberID,
                borrowedAt: .now,
                dueAt: .distantFuture
            )
            
            try await app.test(.DELETE, "games/\(testGameID)",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
            
            let found = try await Game.find(testGameID,
                                            on: app.db)
            
            XCTAssertNotNil(found)
        }
    }
    
    func testDeleteReturnedGameReturnsConflict() async throws {
        try await withApp { app in
            let testMember = try await createMember(app)
            let testMemberID = try XCTUnwrap(testMember.id)
            
            let testGame = try await createGame(app)
            let testGameID = try XCTUnwrap(testGame.id)
            
            try await insertLoan(
                app,
                gameID: testGameID,
                memberID: testMemberID,
                borrowedAt: .distantPast,
                dueAt: .distantPast,
                returnedAt: .now
            )
            
            try await app.test(.DELETE, "games/\(testGameID)",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
            
            let found = try await Game.find(testGameID,
                                            on: app.db)
            
            XCTAssertNotNil(found)
        }
    }

    func testPreflightRequestFromAnotherOriginIsAllowed() async throws {
        try await withApp { app in
            try await app.test(.OPTIONS, "games", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:8080")
                req.headers.replaceOrAdd(name: .accessControlRequestMethod, value: "POST")
                req.headers.replaceOrAdd(name: .accessControlRequestHeaders, value: "content-type")
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .accessControlAllowOrigin), "*")
                XCTAssertTrue(res.headers[.accessControlAllowMethods].joined(separator: ",").contains("POST"))
            })
        }
    }

    func testErrorResponsesCarryTheCorsHeaders() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/not-a-uuid", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:8080")
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
                XCTAssertEqual(res.headers.first(name: .accessControlAllowOrigin), "*")
            })
        }
    }
}
