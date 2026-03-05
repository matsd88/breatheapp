//
//  DailyQuoteWidget.swift
//  MeditationWidget
//
//  Displays rotating inspirational mindfulness quotes
//

import WidgetKit
import SwiftUI

// MARK: - Quote Data

struct MindfulnessQuote {
    let text: String
    let author: String

    static let quotes: [MindfulnessQuote] = [
        MindfulnessQuote(text: "The present moment is filled with joy and happiness. If you are attentive, you will see it.", author: "Thich Nhat Hanh"),
        MindfulnessQuote(text: "Feelings come and go like clouds in a windy sky. Conscious breathing is my anchor.", author: "Thich Nhat Hanh"),
        MindfulnessQuote(text: "Be where you are, not where you think you should be.", author: "Unknown"),
        MindfulnessQuote(text: "The mind is everything. What you think, you become.", author: "Buddha"),
        MindfulnessQuote(text: "Peace comes from within. Do not seek it without.", author: "Buddha"),
        MindfulnessQuote(text: "In today's rush, we all think too much, seek too much, want too much, and forget about the joy of just being.", author: "Eckhart Tolle"),
        MindfulnessQuote(text: "The greatest weapon against stress is our ability to choose one thought over another.", author: "William James"),
        MindfulnessQuote(text: "Almost everything will work again if you unplug it for a few minutes, including you.", author: "Anne Lamott"),
        MindfulnessQuote(text: "Mindfulness is a way of befriending ourselves and our experience.", author: "Jon Kabat-Zinn"),
        MindfulnessQuote(text: "The only way to live is by accepting each minute as an unrepeatable miracle.", author: "Tara Brach"),
        MindfulnessQuote(text: "Breathe. Let go. And remind yourself that this very moment is the only one you know you have for sure.", author: "Oprah Winfrey"),
        MindfulnessQuote(text: "Your calm mind is the ultimate weapon against your challenges.", author: "Bryant McGill"),
        MindfulnessQuote(text: "Quiet the mind, and the soul will speak.", author: "Ma Jaya Sati Bhagavati"),
        MindfulnessQuote(text: "When you realize nothing is lacking, the whole world belongs to you.", author: "Lao Tzu"),
        MindfulnessQuote(text: "Do every act of your life as though it were the very last act of your life.", author: "Marcus Aurelius"),
        MindfulnessQuote(text: "The soul always knows what to do to heal itself. The challenge is to silence the mind.", author: "Caroline Myss"),
        MindfulnessQuote(text: "Within you there is a stillness and a sanctuary to which you can retreat at any time.", author: "Hermann Hesse"),
        MindfulnessQuote(text: "Calmness is the cradle of power.", author: "Josiah Gilbert Holland"),
        MindfulnessQuote(text: "In the midst of movement and chaos, keep stillness inside of you.", author: "Deepak Chopra"),
        MindfulnessQuote(text: "Each morning we are born again. What we do today matters most.", author: "Buddha"),
        MindfulnessQuote(text: "Mindfulness means being awake. It means knowing what you are doing.", author: "Jon Kabat-Zinn"),
        MindfulnessQuote(text: "The little things? The little moments? They aren't little.", author: "Jon Kabat-Zinn"),
        MindfulnessQuote(text: "Nature does not hurry, yet everything is accomplished.", author: "Lao Tzu"),
        MindfulnessQuote(text: "Smile, breathe, and go slowly.", author: "Thich Nhat Hanh"),
        MindfulnessQuote(text: "Life is available only in the present moment.", author: "Thich Nhat Hanh"),
        MindfulnessQuote(text: "The way to live in the present is to remember that this too shall pass.", author: "Unknown"),
        MindfulnessQuote(text: "Surrender to what is. Let go of what was. Have faith in what will be.", author: "Sonia Ricotti"),
        MindfulnessQuote(text: "You cannot control the results, only your actions.", author: "Allan Lokos"),
        MindfulnessQuote(text: "Every moment is a fresh beginning.", author: "T.S. Eliot"),
        MindfulnessQuote(text: "Walk as if you are kissing the Earth with your feet.", author: "Thich Nhat Hanh"),
        MindfulnessQuote(text: "Awareness is the greatest agent for change.", author: "Eckhart Tolle")
    ]

    /// Returns the quote for a specific day (consistent throughout the day)
    static func quoteForDate(_ date: Date) -> MindfulnessQuote {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (dayOfYear - 1) % quotes.count
        return quotes[index]
    }
}

// MARK: - Timeline Provider

struct DailyQuoteTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyQuoteEntry {
        DailyQuoteEntry(
            date: Date(),
            quote: MindfulnessQuote.quotes[0]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyQuoteEntry) -> Void) {
        let quote = MindfulnessQuote.quoteForDate(Date())
        completion(DailyQuoteEntry(date: Date(), quote: quote))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyQuoteEntry>) -> Void) {
        let quote = MindfulnessQuote.quoteForDate(Date())
        let entry = DailyQuoteEntry(date: Date(), quote: quote)

        // Refresh at midnight for new quote
        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

// MARK: - Entry

struct DailyQuoteEntry: TimelineEntry {
    let date: Date
    let quote: MindfulnessQuote
}

// MARK: - Widget Views

struct DailyQuoteWidgetSmallView: View {
    let entry: DailyQuoteEntry

    var body: some View {
        VStack(spacing: 8) {
            // Quote icon
            Image(systemName: "quote.opening")
                .font(.system(size: 16))
                .foregroundStyle(WidgetColors.accentLavender)

            // Quote text (truncated for small widget)
            Text(entry.quote.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            // Author
            Text("- \(entry.quote.author)")
                .font(.system(size: 9, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            ZStack {
                WidgetColors.backgroundGradient

                // Subtle decorative element
                Circle()
                    .fill(WidgetColors.accentPurple.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .offset(x: 60, y: -60)
            }
        }
    }
}

struct DailyQuoteWidgetMediumView: View {
    let entry: DailyQuoteEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side: Decorative quote marks and lotus
            VStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(WidgetColors.accentPurple)

                Spacer()

                // Lotus/meditation icon
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(WidgetColors.accentLavender.opacity(0.5))
            }
            .frame(width: 36)

            // Right side: Quote content
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.quote.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                HStack {
                    Text("- \(entry.quote.author)")
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    Spacer()

                    // Today label
                    Text("Today's Inspiration")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WidgetColors.accentLavender)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WidgetColors.accentPurple.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            ZStack {
                WidgetColors.backgroundGradient

                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        WidgetColors.accentPurple.opacity(0.15),
                        Color.clear
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        }
    }
}

// MARK: - Widget Definition

struct DailyQuoteWidget: Widget {
    let kind = "DailyQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyQuoteTimelineProvider()) { entry in
            DailyQuoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Inspiration")
        .description("Start your day with mindfulness wisdom.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyQuoteWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DailyQuoteEntry

    var body: some View {
        switch family {
        case .systemSmall:
            DailyQuoteWidgetSmallView(entry: entry)
        case .systemMedium:
            DailyQuoteWidgetMediumView(entry: entry)
        default:
            DailyQuoteWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    DailyQuoteWidget()
} timeline: {
    DailyQuoteEntry(date: .now, quote: MindfulnessQuote.quotes[0])
    DailyQuoteEntry(date: .now, quote: MindfulnessQuote.quotes[5])
}

#Preview(as: .systemMedium) {
    DailyQuoteWidget()
} timeline: {
    DailyQuoteEntry(date: .now, quote: MindfulnessQuote.quotes[2])
    DailyQuoteEntry(date: .now, quote: MindfulnessQuote.quotes[10])
}
