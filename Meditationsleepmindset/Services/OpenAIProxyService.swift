//
//  OpenAIProxyService.swift
//  Meditation Sleep Mindset
//

import Foundation

struct OpenAIProxyService {

    // MARK: - Request/Response Types

    struct ChatCompletionRequest: Codable {
        let messages: [MessagePayload]
        let model: String
        let max_tokens: Int
    }

    struct MessagePayload: Codable {
        let role: String
        let content: String
    }

    struct ChatCompletionResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    // MARK: - Errors

    enum ProxyError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case serverError(Int)
        case noResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server URL."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to parse response: \(error.localizedDescription)"
            case .serverError(let code):
                return "Server error (code \(code)). Please try again."
            case .noResponse:
                return "No response received. Please try again."
            }
        }
    }

    // MARK: - Send Message

    static func sendMessage(
        messages: [MessagePayload],
        model: String = Constants.Chat.modelName,
        maxTokens: Int = Constants.Chat.maxTokens
    ) async throws -> String {
        guard let url = URL(string: Constants.Chat.proxyBaseURL) else {
            throw ProxyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body = ChatCompletionRequest(
            messages: messages,
            model: model,
            max_tokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProxyError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyError.noResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProxyError.serverError(httpResponse.statusCode)
        }

        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw ProxyError.decodingError(error)
        }

        guard let content = decoded.choices.first?.message.content else {
            throw ProxyError.noResponse
        }
        return content
    }

    // MARK: - System Prompt Builder

    static func buildSystemPrompt(moodLevel: MoodLevel?, userName: String? = nil) -> String {
        var prompt = """
        You are Breathe AI, a warm and supportive AI wellness assistant in a meditation and sleep app.

        YOUR ROLE:
        - Provide empathetic emotional support and active listening
        - Suggest evidence-based coping techniques (CBT, mindfulness, grounding)
        - Recommend breathing exercises, meditations, or sleep content when appropriate
        - Help users process emotions without judgment

        YOUR BOUNDARIES:
        - You are NOT a therapist and cannot diagnose or treat conditions
        - Never provide medical advice or medication recommendations
        - For serious mental health concerns, gently suggest professional support
        - If someone mentions self-harm or suicide, express concern and provide crisis resources (988 Suicide & Crisis Lifeline)

        YOUR STYLE:
        - Warm, calm, and conversational (not clinical)
        - Use short paragraphs (2-3 sentences max)
        - Ask thoughtful follow-up questions
        - Validate feelings before offering suggestions
        - Occasionally suggest trying a meditation or breathing exercise from the app

        Keep responses concise (under 100 words typically).
        """

        if let mood = moodLevel {
            prompt += "\n\n\(mood.systemPromptContext)"
        }

        if let name = userName {
            prompt += "\n\nThe user's name is \(name)."
        }

        return prompt
    }
}
