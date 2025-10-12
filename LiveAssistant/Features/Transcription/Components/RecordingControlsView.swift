//
//  RecordingControlsView.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// View displaying recording controls and status.
struct RecordingControlsView: View {
    let isRecording: Bool
    let isMicrophoneEnabled: Bool
    let isSystemAudioEnabled: Bool
    let onStart: () async -> Void
    let onStop: () async -> Void
    let onToggleMicrophone: () async -> Void
    let onToggleSystemAudio: () async -> Void
    let onClear: () async -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Recording status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(isRecording ? Color.red.opacity(0.3) : Color.clear, lineWidth: 4)
                            .scaleEffect(isRecording ? 1.5 : 1.0)
                            .opacity(isRecording ? 0 : 1)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isRecording)
                    )

                Text(isRecording ? "Recording" : "Stopped")
                    .font(.headline)
                    .foregroundColor(isRecording ? .red : .secondary)
            }

            Spacer()

            // Source toggles (only visible when recording)
            if isRecording {
                Toggle(
                    isOn: Binding(
                        get: { isMicrophoneEnabled },
                        set: { _ in Task { await onToggleMicrophone() } }
                    )
                ) {
                    Label("Microphone", systemImage: "mic.fill")
                }
                .toggleStyle(.button)
                .tint(isMicrophoneEnabled ? .blue : .gray)

                Toggle(
                    isOn: Binding(
                        get: { isSystemAudioEnabled },
                        set: { _ in Task { await onToggleSystemAudio() } }
                    )
                ) {
                    Label("System Audio", systemImage: "speaker.wave.2.fill")
                }
                .toggleStyle(.button)
                .tint(isSystemAudioEnabled ? .purple : .gray)
            }

            // Main control buttons
            if isRecording {
                Button {
                    Task { await onStop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    Task { await onStart() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
            }

            // Clear button
            Button {
                Task { await onClear() }
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }
}
