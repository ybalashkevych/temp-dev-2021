//
//  TranscriptionSegmentRow.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// A row displaying a single transcription segment.
struct TranscriptionSegmentRow: View {
    let segment: TranscriptionSegment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Speaker badge
            speakerBadge
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                // Timestamp
                Text(formatTime(segment.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Transcribed text
                Text(segment.text)
                    .font(.body)
                    .foregroundColor(segment.isFinal ? .primary : .secondary)
                    .opacity(segment.isFinal ? 1.0 : 0.7)

                // Metadata
                HStack(spacing: 8) {
                    if segment.isQuestion {
                        Label("Question", systemImage: "questionmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if !segment.isFinal {
                        Label("Partial", systemImage: "ellipsis.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Text("Confidence: \(Int(segment.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(segment.isFinal ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder private var speakerBadge: some View {
        VStack(spacing: 4) {
            Image(systemName: segment.speaker == .microphone ? "mic.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
            Text(segment.speaker == .microphone ? "Mic" : "System")
                .font(.caption2)
                .foregroundColor(.white)
        }
        .frame(width: 60, height: 60)
        .background(segment.speaker == .microphone ? Color.blue : Color.purple)
        .cornerRadius(8)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
