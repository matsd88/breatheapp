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

    // MARK: - Text-to-Speech

    struct TTSRequest: Codable {
        let model: String
        let input: String
        let voice: String
        let response_format: String
        let speed: Double
    }

    /// Generate speech audio via OpenAI TTS through the proxy.
    /// Returns raw MP3 data.
    static func generateSpeech(
        text: String,
        voice: String,
        speed: Double = 1.0,
        model: String = Constants.AIMeditation.ttsModel
    ) async throws -> Data {
        guard let url = URL(string: Constants.Chat.proxyBaseURL + "/tts") else {
            throw ProxyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body = TTSRequest(
            model: model,
            input: text,
            voice: voice,
            response_format: "mp3",
            speed: speed
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

        guard !data.isEmpty else {
            throw ProxyError.noResponse
        }

        return data
    }

    // MARK: - System Prompt Builder

    static func buildSystemPrompt(
        moodLevel: MoodLevel?,
        userName: String? = nil,
        coach: WellnessCoach = .general,
        memory: String? = nil,
        healthContext: String? = nil
    ) -> String {
        var prompt = """
        You are Breathe AI, a warm wellness assistant in the Breathe meditation app.

        ROLE: Empathetic support, evidence-based coping (CBT, mindfulness, grounding), recommend app features naturally. Not a therapist — no diagnoses or medical advice. For self-harm/suicide, express concern and share 988 Suicide & Crisis Lifeline.

        APP FEATURES: Guided Meditations (100+ sessions, 3-60 min), AI-Generated Meditations, Sleep Stories, Soundscapes, ASMR, Breathing Exercises, Body Scan, Micro-Moments (1-3 min resets), Programs, Yoga/Movement, Mindset Coaching, Focus Timer, Mood Tracking, Offline Packs, Apple Watch, Sleep Alarm, Playlists.

        STYLE: Warm, calm, conversational. Short paragraphs (2-3 sentences). Validate feelings first. Under 100 words typically.
        """

        // Coach specialization
        prompt += "\n\n\(coach.promptContext)"

        if let mood = moodLevel {
            prompt += "\n\n\(mood.systemPromptContext)"
        }

        if let name = userName {
            prompt += "\n\nThe user's name is \(name)."
        }

        // Long-term memory: durable facts about the user gathered from past conversations.
        if let memory, !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt += "\n\nWHAT YOU REMEMBER ABOUT THIS USER (from past conversations — use naturally, don't recite verbatim):\n\(memory)"
        }

        // Live wellness data so the coach can ground advice in the user's own numbers.
        if let healthContext, !healthContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt += "\n\nTHIS USER'S RECENT WELLNESS DATA (reference naturally when relevant, e.g. tie a suggestion to their sleep or streak; never invent numbers beyond these):\n\(healthContext)"
        }

        return prompt
    }

    /// Asks the model to fold a conversation into a concise, durable memory summary.
    static func summarizeMemory(existingMemory: String, conversation: [MessagePayload]) async throws -> String {
        let transcript = conversation
            .filter { $0.role == "user" || $0.role == "assistant" }
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")

        let instruction = """
        You maintain a long-term memory of a wellness-app user as a short bulleted list of durable, useful facts (recurring stressors, goals, preferences, name, sleep issues, relationships, what helps them). Update the EXISTING MEMORY with anything important from the NEW CONVERSATION. Keep it under 120 words, factual, no fluff, no transient details. Return ONLY the updated bullet list.

        EXISTING MEMORY:
        \(existingMemory.isEmpty ? "(none yet)" : existingMemory)

        NEW CONVERSATION:
        \(transcript)
        """

        let messages: [MessagePayload] = [
            .init(role: "system", content: "You compress conversations into a concise long-term memory."),
            .init(role: "user", content: instruction)
        ]

        return try await sendMessage(messages: messages, maxTokens: 250)
    }
}
