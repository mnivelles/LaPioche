@testable import App
import XCTVapor

final class MemberTests: XCTestCase {
    func testCreateMemberReturnsCreated() async throws {
        try await withApp { app in
            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(MemberInputDTO(name: "Camille", email: "camille@example.com"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                XCTAssertEqual(try res.content.decode(MemberDTO.self).name, "Camille")
            })
        }
    }
    
    func testCreateMemberWithEmptyNameIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(MemberInputDTO(name: "", email: "camille@example.com"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testCreateMemberWithInvalidEmailIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(MemberInputDTO(name: "Camille", email: "not-an-email"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testCreateMemberWithDuplicateEmailReturnsConflict() async throws {
        try await withApp { app in
            _ = try await createMember(app)

            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(MemberInputDTO(name: "Autre", email: "camille@example.com"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
        }
    }
    
    func testShowMember() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            let id = try XCTUnwrap(member.id)
            
            try await app.test(.GET, "members/\(id)") { res async throws in
                XCTAssertEqual(res.status, .ok)
                
                let output = try res.content.decode(MemberDTO.self)
                
                XCTAssertEqual(output.id, id)
                XCTAssertEqual(output.name, member.name)
                XCTAssertEqual(output.email, member.email)
            }
        }
    }

    func testShowUnknownMemberReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.GET, "members/\(UUID())", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testShowMemberWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.GET, "members/not-a-uuid", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateMemberReturnsOk() async throws {
        try await withApp { app in
            let testMember = try await createMember(app)
            let testMemberID = try XCTUnwrap(testMember.id)
            
            let input = MemberInputDTO(name: "Sasha Hamel",
                                       email: "sasha@hamel.me")
            
            try await app.test(.PUT, "members/\(testMemberID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                
                let output = try res.content.decode(MemberDTO.self)
                
                XCTAssertEqual(output.name, input.name)
                XCTAssertEqual(output.email, input.email)
            }
        }
    }
    
    func testUpdateMemberWithEmptyNameIsRejected() async throws {
        try await withApp { app in
            let testMember = try await createMember(app)
            let testMemberID = try XCTUnwrap(testMember.id)
            
            let input = MemberInputDTO(name: "",
                                       email: "sasha@hamel.me")
            
            try await app.test(.PUT, "members/\(testMemberID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testUpdateMemberWithInvalidEmailIsRejected() async throws {
        try await withApp { app in
            let testMember = try await createMember(app)
            let testMemberID = try XCTUnwrap(testMember.id)
            
            let input = MemberInputDTO(name: "Sasha Hamel",
                                       email: "not.an.email")
            
            try await app.test(.PUT, "members/\(testMemberID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testUpdateMemberWithSameEmailReturnsOk() async throws {
        try await withApp { app in
            let testMember = try await createMember(app, email: "sasha@hamel.me")
            let testMemberID = try XCTUnwrap(testMember.id)
            
            let input = MemberInputDTO(name: "Sasha Hamel",
                                       email: "sasha@hamel.me")
            
            try await app.test(.PUT, "members/\(testMemberID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
            }
        }
    }
    
    func testUpdateMemberWithDuplicateEmailReturnsConflict() async throws {
        try await withApp { app in
            _ = try await createMember(app,
                                       email: "sasha@hamel.me")
            
            let testMember = try await createMember(app,
                                                    email: "dominique@durand.fr")
            let testMemberID = try XCTUnwrap(testMember.id)
            
            let input = MemberInputDTO(name: "Sasha Hamel",
                                       email: "sasha@hamel.me")
            
            try await app.test(.PUT, "members/\(testMemberID)") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            }
        }
    }
    
    func testUpdateUnknownMemberReturnsNotFound() async throws {
        try await withApp { app in
            let input = MemberInputDTO(name: "Sasha Hamel",
                                       email: "sasha@hamel.me")
            
            try await app.test(.PUT, "members/\(UUID())") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            }
        }
    }
    
    func testUpdateMemberWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            let input = MemberInputDTO(name: "Sasha Hamel",
                                       email: "sasha@hamel.me")
            
            try await app.test(.PUT, "members/not-a-uuid") { req in
                try req.content.encode(input)
            } afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testDeleteMemberReturnsNoContent() async throws {
        try await withApp { app in
            let testMember = try await createMember(app)
            let testMemberID = try XCTUnwrap(testMember.id)
            
            try await app.test(.DELETE, "members/\(testMemberID)",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .noContent)
            })
            
            let found = try await Member.find(testMemberID,
                                              on: app.db)
            
            XCTAssertNil(found)
        }
    }
    
    func testDeleteMemberUnknownMemberReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.DELETE, "members/\(UUID())",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testDeleteMemberWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.DELETE, "members/not-a-uuid",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testDeleteMemberWithLoansReturnsConflict() async throws {
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
            
            try await app.test(.DELETE, "members/\(testMemberID)",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
            
            let found = try await Member.find(testMemberID,
                                              on: app.db)
            
            XCTAssertNotNil(found)
        }
    }
    
    func testDeleteMemberReturnedGameReturnsConflict() async throws {
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
            
            try await app.test(.DELETE, "members/\(testMemberID)",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
            
            let found = try await Member.find(testMemberID,
                                              on: app.db)
            
            XCTAssertNotNil(found)
        }
    }
    
    func testListLoansReturnsMemberLoans() async throws {
        try await withApp { app in
            let testMember = try await createMember(app)
            let testMemberID = try XCTUnwrap(testMember.id)
            
            let game1 = try await createGame(app)
            let game1ID = try XCTUnwrap(game1.id)
            
            let game2 = try await createGame(app)
            let game2ID = try XCTUnwrap(game2.id)
            
            let loan1 = try await createLoanInDB(app,
                                                 gameID: game1ID,
                                                 memberID: testMemberID,
                                                 borrowedAt: .distantPast,
                                                 dueAt: .distantFuture)
            
            let loan2 = try await createLoanInDB(app,
                                                 gameID: game2ID,
                                                 memberID: testMemberID,
                                                 borrowedAt: .distantPast,
                                                 dueAt: .distantFuture)
            
            try await app.test(.GET, "members/\(testMemberID)/loans",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                
                let output = try res.content.decode([LoanDTO].self)
                let ids = output.map(\.id)
                
                XCTAssert(ids.contains(loan1.id))
                XCTAssert(ids.contains(loan2.id))
            })
        }
    }
    
    func testListLoansReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.GET, "members/\(UUID())/loans",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testListLoansWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.GET, "members/not-a-uuid/loans",
                               afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
}
