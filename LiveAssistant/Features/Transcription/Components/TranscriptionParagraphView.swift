//
//  TranscriptionParagraphView.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/13/25
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// A view displaying a paragraph of transcription text with speaker info and timestamp.
struct TranscriptionParagraphView: View {
    let paragraph: TranscriptionParagraph
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Speaker badge
            speakerBadge
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 8) {
                // Timestamp
                Text(formatTimestamp(paragraph.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)

                // Paragraph text
                Text(paragraph.text)
                    .font(.body)
                    .foregroundColor(paragraph.isFinal ? .primary : .secondary)
                    .opacity(paragraph.isFinal ? 1.0 : 0.7)
                    .textSelection(.enabled)
                    .lineSpacing(4)

                // Metadata bar
                HStack(spacing: 12) {
                    // Question indicator
                    if paragraph.hasQuestion {
                        Label(Strings.Transcription.Segment.question, systemImage: "questionmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    // Partial indicator
                    if !paragraph.isFinal {
                        Label(Strings.Transcription.Segment.partial, systemImage: "ellipsis.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    // Confidence
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .foregroundColor(confidenceColor)
                        Text(Strings.Transcription.Segment.confidence(Int(paragraph.averageConfidence * 100)))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Spacer()

                    // Duration
                    Text(formatDuration(paragraph.duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(isCurrent ? 0.1 : 0.05), radius: isCurrent ? 8 : 4, y: 2)
    }

    @ViewBuilder private var speakerBadge: some View {
        VStack(spacing: 6) {
            Image(systemName: paragraph.speaker == .microphone ? "mic.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
            Text(paragraph.speaker == .microphone ? Strings.Transcription.Speaker.microphone : Strings.Transcription.Speaker.system)
                .font(.caption2)
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
        .background(speakerColor)
        .cornerRadius(10)
    }

    private var backgroundColor: Color {
        if isCurrent {
            return Color.accentColor.opacity(0.05)
        } else if paragraph.isFinal {
            return Color(nsColor: .textBackgroundColor)
        } else {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
    }

    private var speakerColor: Color {
        paragraph.speaker == .microphone ? Color.blue : Color.purple
    }

    private var confidenceIcon: String {
        let confidence = paragraph.averageConfidence
        if confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if confidence >= 0.5 {
            return "exclamationmark.circle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        let confidence = paragraph.averageConfidence
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        if seconds == 0 {
            return "< 1s"
        } else if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
    }
}
