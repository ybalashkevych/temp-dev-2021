//
//  SpeakerType.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Represents the audio source or speaker in a transcription session.
enum SpeakerType: String, Codable, Sendable, CaseIterable {
    /// Audio from the microphone (typically the user/interviewee).
    case microphone

    /// Audio from system output (typically the interviewer or application).
    case systemAudio
}
