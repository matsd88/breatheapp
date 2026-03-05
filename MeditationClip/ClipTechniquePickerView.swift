//
//  ClipTechniquePickerView.swift
//  MeditationClip
//

import SwiftUI

struct ClipTechniquePickerView: View {
    @State private var selectedTechnique: BreathingTechnique?
    @State private var showBreathing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "wind")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.profileAccent)

                            Text("Breathing Exercises")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text("Choose a technique to begin")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 24)

                        // Technique cards
                        VStack(spacing: 12) {
                            ForEach(BreathingTechnique.allCases) { technique in
                                Button {
                                    selectedTechnique = technique
                                    showBreathing = true
                                } label: {
                                    techniqueCard(technique)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Get Full App CTA
                        VStack(spacing: 12) {
                            Text("Want guided meditations, sleep stories & more?")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)

                            Button {
                                openAppStore()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.app.fill")
                                    Text("Get the Full App")
                                }
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .fullScreenCover(isPresented: $showBreathing) {
                if let technique = selectedTechnique {
                    ClipBreathingView(technique: technique)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .clipDirectTechnique)) { notification in
                if let technique = notification.object as? BreathingTechnique {
                    selectedTechnique = technique
                    showBreathing = true
                }
            }
        }
    }

    private func techniqueCard(_ technique: BreathingTechnique) -> some View {
        HStack(spacing: 16) {
            Image(systemName: technique.icon)
                .font(.title2)
                .foregroundStyle(Theme.profileAccent)
                .frame(width: 44, height: 44)
                .background(Theme.profileAccent.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(technique.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(technique.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func openAppStore() {
        let appStoreURL = URL(string: "https://apps.apple.com/app/id6758229420")!
        UIApplication.shared.open(appStoreURL)
    }
}
