import Foundation

struct AIResult: Decodable {
    let title: String
    let summary: String
    let primaryEmotion: String
    let emotionIntensity: Int
    let growthArea: String
    let entryType: String
    let topics: [String]
    let people: [String]
    let loopKey: String
    let insight: String
    let suggestedAction: String
}

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]?
    let error: GeminiError?
}
private struct Candidate: Decodable { let content: Content? }
private struct Content: Decodable { let parts: [Part]? }
private struct Part: Decodable { let text: String? }
private struct GeminiError: Decodable {
    let code: Int?
    let message: String?
    let status: String?
}

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case badResponse(String)
    case noTextReturned
    case invalidJSONFromModel(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing Gemini API key"
        case .badResponse(let msg): return msg
        case .noTextReturned: return "Gemini returned empty text"
        case .invalidJSONFromModel(let msg): return msg
        }
    }
}

final class AIAnalysisService {
    
    private let apiKey: String = "AIzaSyCRZ-nUTzvYK4nzT9KRmldkTuSv3hfdB10"
    private let modelName: String = "gemini-3-flash-preview"
    
    func analyze(text: String) async throws -> AIResult {
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AIServiceError.missingAPIKey
        }
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)")!
        
        let prompt = """
You are NOT a narrator. You are a memory cleaner + pattern spotter.
Rewrite the user's message into a clean, short FIRST-PERSON memory entry.

Rules:
- Always use "I", "my", "me". Never say "the user".
- Keep it real and human. No dramatic storytelling.
- Fix grammar, keep meaning. Don't add facts.
- Title: 3–7 words, punchy.
- summary: 1–2 sentences, first person.
- primaryEmotion: one lowercase word (examples: stress, calm, hurt, angry, happy, anxious, proud, shame, excitement, lonely, overwhelmed).
- emotionIntensity: integer 1..5.
- growthArea: one of [emotional, professional, personal, relationships, health, reflection].
- entryType: one of [memory, thought, emotion, action, dream, goal, reflection].
- topics: 1..5 short lowercase tags (no hashtags).
- people: up to 3 names ONLY if mentioned explicitly; else empty [].
- loopKey: stable snake_case string for repeated patterns (example: friend_conflict_boundaries). If unsure, make a simple one from topics + emotion.
- insight: one sentence, first person.
- suggestedAction: 1–2 sentences, casual Gen-Z best-friend vibe, supportive, not medical, not scary, not “seek therapy” unless user literally asks.

Return ONLY valid JSON with exactly these keys:
title, summary, primaryEmotion, emotionIntensity, growthArea, entryType, topics, people, loopKey, insight, suggestedAction
"""
        
        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt],
                        ["text": "USER_INPUT:\n\(text)"]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.35
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (respData, resp) = try await URLSession.shared.data(for: request)
        
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let raw = String(data: respData, encoding: .utf8) ?? "no body"
            throw AIServiceError.badResponse("HTTP \(http.statusCode): \(raw)")
        }
        
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: respData)
        if let err = decoded.error {
            throw AIServiceError.badResponse("Gemini error \(err.code ?? -1): \(err.message ?? "unknown")")
        }
        
        guard
            let textOut = decoded.candidates?.first?.content?.parts?.compactMap({ $0.text }).joined(),
            !textOut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIServiceError.noTextReturned
        }
        
        guard let jsonData = textOut.data(using: .utf8) else {
            throw AIServiceError.invalidJSONFromModel("Could not convert model output to UTF-8")
        }

        do {
            if let single = try? JSONDecoder().decode(AIResult.self, from: jsonData) {
                return normalize(single)
            }
            

            if let array = try? JSONDecoder().decode([AIResult].self, from: jsonData),
               let first = array.first {
                return normalize(first)
            }
            
            throw AIServiceError.invalidJSONFromModel("JSON shape mismatch")
            
        } catch {
            throw AIServiceError.invalidJSONFromModel("Model output was not valid JSON:\n\(textOut)")
        }
        
    }
    private func normalize(_ result: AIResult) -> AIResult {
        AIResult(
            title: result.title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: result.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryEmotion: result.primaryEmotion.lowercased(),
            emotionIntensity: max(1, min(result.emotionIntensity, 5)),
            growthArea: result.growthArea.lowercased(),
            entryType: result.entryType.lowercased(),
            topics: Array(result.topics.map { $0.lowercased() }.prefix(5)),
            people: Array(result.people.prefix(3)),
            loopKey: result.loopKey.lowercased(),
            insight: result.insight.trimmingCharacters(in: .whitespacesAndNewlines),
            suggestedAction: result.suggestedAction.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

}
