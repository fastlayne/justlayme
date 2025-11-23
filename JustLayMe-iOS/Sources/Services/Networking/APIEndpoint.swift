import Foundation
import Alamofire

// MARK: - API Endpoint Definition
struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let headers: HTTPHeaders
    let body: Encodable?

    init(
        path: String,
        method: HTTPMethod = .get,
        headers: HTTPHeaders = [:],
        body: Encodable? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
    }
}

// MARK: - Auth Endpoints
extension APIEndpoint {
    static func login(email: String, password: String) -> APIEndpoint {
        struct Body: Encodable {
            let email: String
            let password: String
        }
        return APIEndpoint(
            path: "api/login",
            method: .post,
            body: Body(email: email, password: password)
        )
    }

    static func register(email: String, password: String) -> APIEndpoint {
        struct Body: Encodable {
            let email: String
            let password: String
        }
        return APIEndpoint(
            path: "api/register",
            method: .post,
            body: Body(email: email, password: password)
        )
    }

    static func googleAuth(credential: String) -> APIEndpoint {
        return APIEndpoint(
            path: "api/auth/google",
            method: .post,
            body: GoogleAuthRequest(credential: credential)
        )
    }

    static var verifyToken: APIEndpoint {
        APIEndpoint(path: "api/verify")
    }

    static func resendVerification(email: String) -> APIEndpoint {
        struct Body: Encodable {
            let email: String
        }
        return APIEndpoint(
            path: "api/resend-verification",
            method: .post,
            body: Body(email: email)
        )
    }
}

// MARK: - Chat Endpoints
extension APIEndpoint {
    static func sendMessage(message: String, characterId: String, userId: String?) -> APIEndpoint {
        return APIEndpoint(
            path: "api/chat",
            method: .post,
            body: ChatRequest(message: message, characterId: characterId, userId: userId)
        )
    }

    static func sendFeedback(memoryId: String, score: Int, correctedResponse: String?, patternType: String?) -> APIEndpoint {
        struct Body: Encodable {
            let score: Int
            let correctedResponse: String?
            let patternType: String?

            enum CodingKeys: String, CodingKey {
                case score
                case correctedResponse = "corrected_response"
                case patternType = "pattern_type"
            }
        }
        return APIEndpoint(
            path: "api/feedback/\(memoryId)",
            method: .post,
            body: Body(score: score, correctedResponse: correctedResponse, patternType: patternType)
        )
    }
}

// MARK: - Character Endpoints
extension APIEndpoint {
    static var characters: APIEndpoint {
        APIEndpoint(path: "api/characters")
    }

    static func createCharacter(_ request: CreateCharacterRequest) -> APIEndpoint {
        APIEndpoint(
            path: "api/characters",
            method: .post,
            body: request
        )
    }

    static func updateCharacter(id: String, traits: [String]?, backstory: String?, patterns: [String]?) -> APIEndpoint {
        struct Body: Encodable {
            let personalityTraits: [String]?
            let backstory: String?
            let speechPatterns: [String]?

            enum CodingKeys: String, CodingKey {
                case personalityTraits = "personality_traits"
                case backstory
                case speechPatterns = "speech_patterns"
            }
        }
        return APIEndpoint(
            path: "api/characters/\(id)",
            method: .put,
            body: Body(personalityTraits: traits, backstory: backstory, speechPatterns: patterns)
        )
    }

    static func characterCustomizationOptions(id: String) -> APIEndpoint {
        APIEndpoint(path: "api/characters/\(id)/customization-options")
    }

    static func customizeCharacter(id: String, customization: CharacterCustomization) -> APIEndpoint {
        APIEndpoint(
            path: "api/characters/\(id)/customize",
            method: .post,
            body: customization
        )
    }

    static func previewPrompt(characterId: String) -> APIEndpoint {
        APIEndpoint(path: "api/characters/\(characterId)/preview-prompt")
    }
}

// MARK: - Conversation Endpoints
extension APIEndpoint {
    static func conversations(page: Int = 1, limit: Int = 20) -> APIEndpoint {
        APIEndpoint(path: "api/conversations?page=\(page)&limit=\(limit)")
    }

    static func conversationMessages(id: String) -> APIEndpoint {
        APIEndpoint(path: "api/conversations/\(id)/messages")
    }

    static func searchConversations(query: String) -> APIEndpoint {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return APIEndpoint(path: "api/conversations/search?q=\(encoded)")
    }

    static func archiveConversation(id: String) -> APIEndpoint {
        APIEndpoint(
            path: "api/conversations/\(id)/archive",
            method: .post
        )
    }

    static func deleteConversation(id: String) -> APIEndpoint {
        APIEndpoint(
            path: "api/conversations/\(id)",
            method: .delete
        )
    }

    static func exportConversation(id: String) -> APIEndpoint {
        APIEndpoint(path: "api/conversations/\(id)/export")
    }
}

// MARK: - Model Endpoints
extension APIEndpoint {
    static var models: APIEndpoint {
        APIEndpoint(path: "api/models")
    }

    static func testModel(model: String, prompt: String) -> APIEndpoint {
        struct Body: Encodable {
            let model: String
            let prompt: String
        }
        return APIEndpoint(
            path: "api/models/test",
            method: .post,
            body: Body(model: model, prompt: prompt)
        )
    }

    static var modelsHealth: APIEndpoint {
        APIEndpoint(path: "api/models/health")
    }

    static func modelRecommendation(characterId: String, userId: String?) -> APIEndpoint {
        var path = "api/models/recommendations/\(characterId)"
        if let userId = userId {
            path += "?user_id=\(userId)"
        }
        return APIEndpoint(path: path)
    }
}

// MARK: - Profile Endpoints
extension APIEndpoint {
    static var profile: APIEndpoint {
        APIEndpoint(path: "api/profile")
    }

    static func updateProfile(_ request: ProfileUpdateRequest) -> APIEndpoint {
        APIEndpoint(
            path: "api/profile",
            method: .put,
            body: request
        )
    }
}

// MARK: - Data Management Endpoints
extension APIEndpoint {
    static var exportData: APIEndpoint {
        APIEndpoint(path: "api/export-data")
    }

    static var clearData: APIEndpoint {
        APIEndpoint(
            path: "api/clear-data",
            method: .delete
        )
    }
}

// MARK: - Payment Endpoints
extension APIEndpoint {
    static func createCheckoutSession(plan: String, userId: String?, email: String?) -> APIEndpoint {
        APIEndpoint(
            path: "api/create-checkout-session",
            method: .post,
            body: CheckoutSessionRequest(plan: plan, userId: userId, userEmail: email)
        )
    }
}
