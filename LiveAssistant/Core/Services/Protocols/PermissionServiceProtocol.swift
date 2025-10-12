//
//  PermissionServiceProtocol.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Defines the interface for managing application permissions.
protocol PermissionServiceProtocol: Sendable {
    /// Checks the current authorization status for microphone access.
    func checkMicrophonePermission() async -> PermissionStatus

    /// Requests microphone access from the user.
    func requestMicrophonePermission() async -> PermissionStatus

    /// Checks the current authorization status for speech recognition.
    func checkSpeechRecognitionPermission() async -> PermissionStatus

    /// Requests speech recognition access from the user.
    func requestSpeechRecognitionPermission() async -> PermissionStatus

    /// Checks the current authorization status for screen recording (system audio).
    func checkScreenRecordingPermission() async -> PermissionStatus

    /// Requests screen recording access from the user.
    /// - Note: This will prompt the user to enable screen recording in System Settings.
    func requestScreenRecordingPermission() async -> PermissionStatus

    /// Checks if all required permissions for transcription are granted.
    func checkAllTranscriptionPermissions() async -> Bool
}

/// Represents the status of a permission request.
enum PermissionStatus: Sendable {
    /// Permission has been granted.
    case authorized

    /// Permission has been denied by the user.
    case denied

    /// Permission status is not determined yet.
    case notDetermined

    /// Permission is restricted (e.g., parental controls).
    case restricted

    var isGranted: Bool {
        self == .authorized
    }
}
