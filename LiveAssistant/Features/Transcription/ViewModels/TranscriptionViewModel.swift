//
//  TranscriptionViewModel.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// ViewModel for managing transcription state and user actions.
@Observable
@MainActor
final class TranscriptionViewModel {
    private let transcriptionRepository: TranscriptionRepositoryProtocol
    private let permissionService: PermissionServiceProtocol

    // MARK: - State

    private(set) var segments: [TranscriptionSegment] = []
    private(set) var isRecording = false
    private(set) var isMicrophoneEnabled = false
    private(set) var isSystemAudioEnabled = false
    private(set) var error: String?
    private(set) var permissionsGranted = false
    private(set) var isCheckingPermissions = false

    // Individual permission states for UI feedback
    private(set) var microphonePermissionStatus: PermissionStatus = .notDetermined
    private(set) var speechRecognitionPermissionStatus: PermissionStatus = .notDetermined
    private(set) var screenRecordingPermissionStatus: PermissionStatus = .notDetermined

    private var segmentStreamTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        transcriptionRepository: TranscriptionRepositoryProtocol,
        permissionService: PermissionServiceProtocol
    ) {
        self.transcriptionRepository = transcriptionRepository
        self.permissionService = permissionService
    }

    // MARK: - Actions

    /// Checks all required permissions without requesting them.
    func checkPermissions() async {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }

        microphonePermissionStatus = await permissionService.checkMicrophonePermission()
        speechRecognitionPermissionStatus = await permissionService.checkSpeechRecognitionPermission()
        screenRecordingPermissionStatus = await permissionService.checkScreenRecordingPermission()

        permissionsGranted =
            microphonePermissionStatus.isGranted
            && speechRecognitionPermissionStatus.isGranted
            && screenRecordingPermissionStatus.isGranted
    }

    /// Requests all required permissions from the user.
    func requestPermissions() async {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }

        print("🎤 Requesting microphone permission...")
        // Request microphone permission
        if microphonePermissionStatus != .authorized {
            microphonePermissionStatus = await permissionService.requestMicrophonePermission()
            print("🎤 Microphone permission result: \(microphonePermissionStatus)")
        }

        print("🗣️ Requesting speech recognition permission...")
        // Request speech recognition permission
        if speechRecognitionPermissionStatus != .authorized {
            speechRecognitionPermissionStatus = await permissionService.requestSpeechRecognitionPermission()
            print("🗣️ Speech recognition permission result: \(speechRecognitionPermissionStatus)")
        }

        print("🖥️ Requesting screen recording permission...")
        // Request screen recording permission
        if screenRecordingPermissionStatus != .authorized {
            screenRecordingPermissionStatus = await permissionService.requestScreenRecordingPermission()
            print("🖥️ Screen recording permission result: \(screenRecordingPermissionStatus)")
        }

        permissionsGranted =
            microphonePermissionStatus.isGranted
            && speechRecognitionPermissionStatus.isGranted
            && screenRecordingPermissionStatus.isGranted

        print("✅ All permissions granted: \(permissionsGranted)")
    }

    /// Starts the transcription session.
    func start() async {
        guard permissionsGranted else {
            error = "Please grant all required permissions to start transcription"
            return
        }

        error = nil

        // Start listening to segments
        startListeningToSegments()

        // Start with microphone enabled by default
        if !isMicrophoneEnabled {
            await toggleMicrophone()
        }

        isRecording = true
    }

    /// Stops the transcription session.
    func stop() async {
        await transcriptionRepository.stopAll()
        segmentStreamTask?.cancel()
        segmentStreamTask = nil
        isRecording = false
        isMicrophoneEnabled = false
        isSystemAudioEnabled = false
    }

    /// Toggles microphone transcription on/off.
    func toggleMicrophone() async {
        do {
            if isMicrophoneEnabled {
                await transcriptionRepository.stopMicrophone()
                isMicrophoneEnabled = false
            } else {
                try await transcriptionRepository.startMicrophone()
                isMicrophoneEnabled = true
                error = nil
            }
        } catch {
            self.error = "Failed to toggle microphone: \(error.localizedDescription)"
        }
    }

    /// Toggles system audio transcription on/off.
    func toggleSystemAudio() async {
        do {
            if isSystemAudioEnabled {
                await transcriptionRepository.stopSystemAudio()
                isSystemAudioEnabled = false
            } else {
                try await transcriptionRepository.startSystemAudio()
                isSystemAudioEnabled = true
                error = nil
            }
        } catch {
            self.error = "Failed to toggle system audio: \(error.localizedDescription)"
        }
    }

    /// Clears all transcription segments.
    func clear() async {
        segments.removeAll()
        await transcriptionRepository.clearSession()
    }

    /// Dismisses the current error message.
    func dismissError() {
        error = nil
    }

    // MARK: - Private Methods

    private func startListeningToSegments() {
        segmentStreamTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = self.transcriptionRepository.streamSegments()

            for await segment in stream {
                await self.handleNewSegment(segment)
            }
        }
    }

    private func handleNewSegment(_ segment: TranscriptionSegment) async {
        if segment.isFinal {
            // Replace any partial segment with the same approximate timing with the final one
            if let index = segments.firstIndex(where: {
                !$0.isFinal
                    && $0.speaker == segment.speaker
                    && abs($0.startTime - segment.startTime) < 1.0
            }) {
                segments[index] = segment
            } else {
                segments.append(segment)
            }
        } else {
            // Add or update partial segment
            if let index = segments.firstIndex(where: {
                !$0.isFinal
                    && $0.speaker == segment.speaker
                    && abs($0.startTime - segment.startTime) < 1.0
            }) {
                segments[index] = segment
            } else {
                segments.append(segment)
            }
        }
    }
}
