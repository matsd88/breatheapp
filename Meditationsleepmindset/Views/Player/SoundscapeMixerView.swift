//
//  SoundscapeMixerView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct SoundscapeMixerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var ambientManager = AmbientSoundManager.shared
    @State private var appeared = false
    @State private var selectedSleepDuration: Int = 30

    private let sheetBackground = Color(red: 0.06, green: 0.08, blue: 0.14)
    private let sleepDurations = [15, 30, 45, 60]

    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    sheetBackground,
                    sheetBackground.opacity(0.95),
                    Color.black.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Handle with subtle glow
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .shadow(color: .white.opacity(0.1), radius: 4)
                    .padding(.top, 14)

                // Header with icon
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.title3)
                            .foregroundStyle(.cyan.opacity(0.8))

                        Text("Ambient Sounds")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Text(ambientManager.activeSounds.isEmpty ? "Layer sounds over your content" : "\(ambientManager.activeSounds.count) of 3 active")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -10)

                // Sleep Mode Toggle
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .font(.subheadline)
                            .foregroundStyle(ambientManager.sleepModeEnabled ? .cyan : .white.opacity(0.5))

                        Text("Sleep Mode")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { ambientManager.sleepModeEnabled },
                            set: { enabled in
                                if enabled {
                                    HapticManager.selection()
                                    ambientManager.enableSleepMode(duration: Double(selectedSleepDuration * 60))
                                } else {
                                    HapticManager.light()
                                    ambientManager.disableSleepMode()
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(.cyan)
                    }

                    if ambientManager.sleepModeEnabled || !ambientManager.activeSounds.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(sleepDurations, id: \.self) { duration in
                                Text("\(duration)m")
                                    .font(.caption.weight(selectedSleepDuration == duration ? .semibold : .regular))
                                    .foregroundStyle(selectedSleepDuration == duration ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedSleepDuration == duration ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .onTapGesture {
                                        HapticManager.selection()
                                        selectedSleepDuration = duration
                                        if ambientManager.sleepModeEnabled {
                                            ambientManager.enableSleepMode(duration: Double(duration * 60))
                                        }
                                    }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -5)

                // Sound grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(Array(ambientManager.availableSounds.enumerated()), id: \.element.id) { index, sound in
                            SoundMixerTile(
                                sound: sound,
                                isActive: ambientManager.isActive(sound),
                                isLoading: ambientManager.isLoadingSound(sound),
                                volume: ambientManager.volume(for: sound),
                                onToggle: {
                                    HapticManager.light()
                                    ambientManager.toggleSound(sound)
                                },
                                onVolumeChange: { ambientManager.setVolume(for: sound, volume: $0) }
                            )
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.03), value: appeared)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Active sound volume sliders
                if !ambientManager.activeSounds.isEmpty {
                    VStack(spacing: 12) {
                        // Divider with gradient
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.15), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 20)

                        Text("Volume Mix")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .textCase(.uppercase)
                            .tracking(1)

                        ForEach(ambientManager.availableSounds.filter { ambientManager.isActive($0) }) { sound in
                            HStack(spacing: 12) {
                                Image(systemName: sound.iconName)
                                    .font(.caption)
                                    .foregroundStyle(.cyan.opacity(0.7))
                                    .frame(width: 20)

                                Text(sound.name)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 70, alignment: .leading)

                                Slider(
                                    value: Binding(
                                        get: { ambientManager.volume(for: sound) },
                                        set: { ambientManager.setVolume(for: sound, volume: $0) }
                                    ),
                                    in: 0...1
                                )
                                .tint(.cyan.opacity(0.7))
                            }
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: ambientManager.activeSounds.count)
                }

                // Reset button
                if !ambientManager.activeSounds.isEmpty {
                    Button {
                        HapticManager.medium()
                        ambientManager.resetAll()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                            Text("Stop All Sounds")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.65), .large])
        .presentationBackground(sheetBackground)
        .presentationDragIndicator(.hidden)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

struct SoundMixerTile: View {
    let sound: AmbientSound
    let isActive: Bool
    let isLoading: Bool
    let volume: Double
    let onToggle: () -> Void
    let onVolumeChange: (Double) -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: sound.iconName)
                            .font(.title3)
                            .foregroundStyle(isActive ? .black : .white.opacity(0.7))
                    }
                }
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(isActive ? Color.white : Color.white.opacity(0.08))
                        .shadow(color: isActive ? .white.opacity(0.2) : .clear, radius: 8)
                )
                .overlay(
                    Circle()
                        .stroke(isActive ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                )

                Text(sound.name)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))
                    .lineLimit(1)
            }
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(.plain)
    }
}
