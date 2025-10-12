//
//  PermissionRequestView.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// View for requesting and displaying permission status.
struct PermissionRequestView: View {
    let microphoneStatus: PermissionStatus
    let speechRecognitionStatus: PermissionStatus
    let screenRecordingStatus: PermissionStatus
    let isChecking: Bool
    let onRequestPermissions: () async -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Permissions Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("LiveAssistant needs the following permissions to provide real-time transcription:")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "To transcribe your voice",
                    status: microphoneStatus
                )

                PermissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "To convert speech to text",
                    status: speechRecognitionStatus
                )

                PermissionRow(
                    icon: "display",
                    title: "Screen Recording",
                    description: "To capture system audio",
                    status: screenRecordingStatus
                )
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            if allPermissionsGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All permissions granted!")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            } else {
                Button {
                    Task { await onRequestPermissions() }
                } label: {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "lock.open.fill")
                        }
                        Text(isChecking ? "Checking..." : "Grant Permissions")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isChecking)
            }
        }
        .frame(maxWidth: 500)
        .padding()
    }

    private var allPermissionsGranted: Bool {
        microphoneStatus.isGranted && speechRecognitionStatus.isGranted && screenRecordingStatus.isGranted
    }
}

/// Row displaying a single permission status.
struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    @ViewBuilder private var statusBadge: some View {
        switch status {
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .denied, .restricted:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .notDetermined:
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        }
    }
}
