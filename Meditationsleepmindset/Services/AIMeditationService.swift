//
//  AIMeditationService.swift
//  Meditation Sleep Mindset
//
//  Service for generating personalized AI meditations using OpenAI for script
//  generation and OpenAI TTS for text-to-speech conversion.
//

import Foundation
import AVFoundation
import SwiftData

// Note: AIMeditationDuration, AIMeditationFocus, AIMeditationVoice, AIMeditationBackground,
// and AIMeditationRequest are defined in AIGeneratedMeditation.swift

// MARK: - AI Meditation Service

@MainActor
class AIMeditationService: ObservableObject {
    static let shared = AIMeditationService()

    // MARK: - Published State
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var generationStatus: String = ""
    @Published var error: String?
    @Published var showError = false

    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var progressTimer: Timer?
    private var targetProgress: Double = 0
    private var generatedMeditationsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documentsPath.appendingPathComponent("GeneratedMeditations", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    private init() {}

    // MARK: - Script Generation Prompt

    private func buildMeditationPrompt(for request: AIMeditationRequest) -> String {
        var prompt = """
        You are an expert meditation guide. Create a calming, professional meditation script.

        REQUIREMENTS:
        - Duration: approximately \(request.duration.rawValue) minutes (\(request.duration.approximateWordCount) words)
        - Focus: \(request.focus.displayName) (\(request.focus.promptContext))
        - Style: Calm, soothing, and grounding

        STRUCTURE:
        1. Opening (10%): Gentle welcome, setting intention, initial breathing guidance
        2. Breathing Exercise (15%): Slow, deep breathing instructions (4-7-8 or similar)
        3. Main Practice (55%): Body scan, visualization, or focus-specific techniques
        4. Integration (15%): Gentle awareness, absorbing benefits
        5. Closing (5%): Gradual return, final affirmation

        STYLE GUIDELINES:
        - Use second person ("you")
        - Include natural pauses (marked with ...)
        - Speak slowly and gently
        - Include body awareness cues
        - Use calming imagery appropriate to the focus
        - Avoid complex or jarring language
        - Include affirmations related to the focus area

        """

        if let note = request.personalNote, !note.isEmpty {
            prompt += """

            PERSONALIZATION:
            The user shared: "\(note)"
            Weave this context naturally into the meditation without quoting it directly.

            """
        }

        prompt += """

        Write the complete meditation script now. Do not include stage directions or [brackets].
        Start directly with the meditation guidance.
        """

        return prompt
    }

    // MARK: - Generate Meditation

    /// Generate a complete AI meditation
    /// - Parameters:
    ///   - request: The meditation configuration
    ///   - context: SwiftData model context for saving
    /// - Returns: The generated meditation content for playback
    func generateMeditation(request: AIMeditationRequest, context: ModelContext) async throws -> AIGeneratedMeditation {
        isGenerating = true
        generationProgress = 0
        error = nil

        defer {
            stopProgressTimer()
            isGenerating = false
        }

        // Check for cached meditation (SwiftData + audio file)
        if let cached = getCachedMeditation(for: request.cacheKey, in: context) {
            generationProgress = 1.0
            generationStatus = "Using cached meditation"
            return cached
        }

        do {
            // Step 1: Generate script with OpenAI
            generationStatus = "Creating your personalized script..."
            startSmoothProgress(from: 0.02, to: 0.38, estimatedSeconds: 15)

            let script = try await generateScript(for: request)
            stopProgressTimer()
            generationProgress = 0.40

            // Step 2: Convert to speech with OpenAI TTS
            generationStatus = "Recording with AI voice..."
            startSmoothProgress(from: 0.40, to: 0.88, estimatedSeconds: 30)

            let audioURL = try await generateAudio(script: script, voice: request.voice, cacheKey: request.cacheKey)
            stopProgressTimer()
            generationProgress = 0.90

            // Step 3: Get audio duration
            generationStatus = "Finalizing..."
            let duration = try await getAudioDuration(url: audioURL)

            // Step 4: Create and save the meditation
            generationStatus = "Saving your meditation..."
            generationProgress = 0.95
            let meditation = AIGeneratedMeditation(
                title: generateTitle(for: request),
                script: script,
                audioFileURL: audioURL.lastPathComponent,
                durationSeconds: Int(duration),
                focus: request.focus.rawValue,
                voice: request.voice.rawValue,
                background: request.background.rawValue
            )

            context.insert(meditation)
            try context.save()

            generationProgress = 1.0
            generationStatus = "Complete!"

            return meditation

        } catch {
            self.error = error.localizedDescription
            self.showError = true
            throw error
        }
    }

    // MARK: - Smooth Progress Animation

    /// Smoothly animates progress from `from` to `to` over an estimated duration.
    /// Uses an ease-out curve so it starts faster and slows down as it approaches the target,
    /// giving a natural feel even if the actual task takes longer than estimated.
    private func startSmoothProgress(from start: Double, to end: Double, estimatedSeconds: Double) {
        stopProgressTimer()
        generationProgress = start
        targetProgress = end

        let tickInterval: Double = 0.3 // Update every 300ms for smooth movement
        let totalTicks = estimatedSeconds / tickInterval
        var tickCount: Double = 0

        progressTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                tickCount += 1

                // Ease-out curve: fast at start, slows near the end
                // Progress approaches target but never quite reaches it
                let linearProgress = min(tickCount / totalTicks, 1.0)
                // Use a curve that reaches ~92% of the range, leaving room for the actual completion
                let easedProgress = 1.0 - pow(1.0 - linearProgress, 2.5)
                let maxReach = 0.92 // Don't go past 92% of the range while waiting

                let range = end - start
                let newProgress = start + (range * easedProgress * maxReach)

                if newProgress > self.generationProgress {
                    self.generationProgress = newProgress
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Script Generation

    private func generateScript(for request: AIMeditationRequest) async throws -> String {
        let prompt = buildMeditationPrompt(for: request)

        let messages: [OpenAIProxyService.MessagePayload] = [
            .init(role: "system", content: "You are a professional meditation guide creating calming, therapeutic meditation scripts."),
            .init(role: "user", content: prompt)
        ]

        // Use higher token limit for longer scripts
        let maxTokens = min(4000, request.duration.approximateWordCount * 2)

        let script = try await OpenAIProxyService.sendMessage(
            messages: messages,
            model: Constants.AIMeditation.scriptModel,
            maxTokens: maxTokens
        )

        return script
    }

    // MARK: - Audio Generation

    private func generateAudio(script: String, voice: AIMeditationVoice, cacheKey: String) async throws -> URL {
        let data = try await OpenAIProxyService.generateSpeech(
            text: script,
            voice: voice.openAIVoice,
            speed: voice.speechSpeed
        )

        // Save audio file
        let audioFileName = "\(cacheKey).mp3"
        let audioURL = generatedMeditationsDirectory.appendingPathComponent(audioFileName)
        try data.write(to: audioURL)

        return audioURL
    }

    // MARK: - Helpers

    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }

    private func generateTitle(for request: AIMeditationRequest) -> String {
        let focusName = request.focus.displayName
        let durationText = "\(request.duration.rawValue)m"
        return "\(focusName) - \(durationText)"
    }

    private func getCachedMeditation(for cacheKey: String, in context: ModelContext) -> AIGeneratedMeditation? {
        // Check if audio file exists on disk
        let audioFileName = "\(cacheKey).mp3"
        let audioURL = generatedMeditationsDirectory.appendingPathComponent(audioFileName)

        guard fileManager.fileExists(atPath: audioURL.path) else {
            return nil
        }

        // Query SwiftData for the matching meditation
        let descriptor = FetchDescriptor<AIGeneratedMeditation>(
            predicate: #Predicate { $0.audioFileURL == audioFileName },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    /// Get the full file URL for a generated meditation's audio
    func getAudioFileURL(for meditation: AIGeneratedMeditation) -> URL {
        return generatedMeditationsDirectory.appendingPathComponent(meditation.audioFileURL)
    }

    /// Delete a generated meditation and its audio file
    func deleteMeditation(_ meditation: AIGeneratedMeditation, context: ModelContext) {
        // Delete audio file
        let audioURL = getAudioFileURL(for: meditation)
        try? fileManager.removeItem(at: audioURL)

        // Delete from SwiftData
        context.delete(meditation)
        try? context.save()
    }

    /// Get all generated meditations
    func getGeneratedMeditations(context: ModelContext) -> [AIGeneratedMeditation] {
        let descriptor = FetchDescriptor<AIGeneratedMeditation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - Errors

enum AIMeditationError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError(Int)
    case apiError(String)
    case audioGenerationFailed
    case scriptGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint."
        case .networkError:
            return "Network error. Please check your connection."
        case .serverError(let code):
            return "Server error (code \(code)). Please try again."
        case .apiError(let message):
            return message
        case .audioGenerationFailed:
            return "Failed to generate audio. Please try again."
        case .scriptGenerationFailed:
            return "Failed to generate meditation script. Please try again."
        }
    }
}
