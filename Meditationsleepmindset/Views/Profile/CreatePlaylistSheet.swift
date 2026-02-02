//
//  CreatePlaylistSheet.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct CreatePlaylistSheet: View {
    @Binding var playlistName: String
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    private var canCreate: Bool {
        !playlistName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 50))
                        .foregroundStyle(Theme.profileAccent)

                    Text("New Playlist")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    TextField("", text: $playlistName, prompt: Text("Playlist name").foregroundStyle(.white.opacity(0.4)))
                        .font(.body)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isNameFocused)
                        .onSubmit {
                            if canCreate {
                                onCreate()
                                dismiss()
                            }
                        }
                        .padding(.horizontal)

                    Button {
                        onCreate()
                        dismiss()
                    } label: {
                        Text("Create")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canCreate ? Theme.profileAccent : Theme.profileAccent.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canCreate)
                    .padding(.horizontal)

                    Button("Cancel") {
                        playlistName = ""
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.6))

                    Spacer()
                }
                .frame(maxWidth: 500)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.profileGradient)
        .onAppear {
            isNameFocused = true
        }
    }
}
