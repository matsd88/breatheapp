//
//  EnergyScheduleView.swift
//  Meditation Sleep Mindset
//
//  Shows the day's forecast energy curve and circadian windows, with a contextual
//  suggestion for the window you're in right now.
//

import SwiftUI

struct EnergyScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var circadian = CircadianService.shared
    @State private var wakeTime: Date = Date()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    var body: some View {
        let schedule = circadian.schedule()
        let current = circadian.currentWindow()

        return NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your energy today")
                                .font(.title2.weight(.bold)).foregroundStyle(.white)
                            Text("Forecast from your wake time. Meditate with your rhythm, not against it.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                        }

                        EnergyCurve(points: schedule.points, now: Date())
                            .frame(height: 150)
                            .padding()
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        if let current {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(current.type.title, systemImage: current.type.icon)
                                    .font(.headline).foregroundStyle(Theme.profileAccent)
                                Text(current.type.suggestion)
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Theme.profileAccent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // Windows list
                        VStack(spacing: 0) {
                            ForEach(schedule.windows) { w in
                                HStack(spacing: 12) {
                                    Image(systemName: w.type.icon).foregroundStyle(Theme.profileAccent).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.type.title).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                                        Text("\(timeFormatter.string(from: w.start)) – \(timeFormatter.string(from: w.end))")
                                            .font(.caption).foregroundStyle(.white.opacity(0.55))
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                if w.id != schedule.windows.last?.id {
                                    Divider().background(Color.white.opacity(0.08))
                                }
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Wake-time setting
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your usual wake time").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .onChange(of: wakeTime) { _, newValue in
                                    let cal = Calendar.current
                                    let comps = cal.dateComponents([.hour, .minute], from: newValue)
                                    circadian.wakeTimeSeconds = Double((comps.hour ?? 7) * 3600 + (comps.minute ?? 0) * 60)
                                }
                            Text("Suggested bedtime: \(timeFormatter.string(from: schedule.suggestedBedtime))")
                                .font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        Spacer(minLength: 40)
                    }
                    .padding()
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Energy Forecast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .onAppear {
                wakeTime = Calendar.current.startOfDay(for: Date()).addingTimeInterval(circadian.wakeTimeSeconds)
            }
        }
    }
}

/// Lightweight filled energy curve (no Charts dependency) with a "now" marker.
private struct EnergyCurve: View {
    let points: [CircadianService.EnergyPoint]
    let now: Date

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let levels = points.map { $0.level }
            let count = max(1, levels.count - 1)

            // Curve path
            let line = Path { p in
                for (i, lvl) in levels.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(count)
                    let y = h * (1 - CGFloat(lvl))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            let fill = Path { p in
                p.move(to: CGPoint(x: 0, y: h))
                for (i, lvl) in levels.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(count)
                    let y = h * (1 - CGFloat(lvl))
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
            }

            // "Now" x-position based on time between first and last point.
            let nowX: CGFloat = {
                guard let first = points.first?.date, let last = points.last?.date, last > first else { return 0 }
                let frac = max(0, min(1, now.timeIntervalSince(first) / last.timeIntervalSince(first)))
                return w * CGFloat(frac)
            }()

            ZStack(alignment: .topLeading) {
                fill.fill(
                    LinearGradient(colors: [Theme.profileAccent.opacity(0.5), Theme.profileAccent.opacity(0.05)],
                                   startPoint: .top, endPoint: .bottom)
                )
                line.stroke(Theme.profileAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1.5).offset(x: nowX)
            }
        }
    }
}

#Preview {
    EnergyScheduleView()
}
