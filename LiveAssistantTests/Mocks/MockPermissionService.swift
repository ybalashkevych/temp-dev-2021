//
//  MockPermissionService.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation
@testable import LiveAssistant

/// Mock implementation of PermissionServiceProtocol for testing.
final class MockPermissionService: PermissionServiceProtocol {
    var microphoneStatus: PermissionStatus = .notDetermined
    var speechRecognitionStatus: PermissionStatus = .notDetermined
    var screenRecordingStatus: PermissionStatus = .notDetermined

    var checkMicrophoneCallCount = 0
    var requestMicrophoneCallCount = 0
    var checkSpeechRecognitionCallCount = 0
    var requestSpeechRecognitionCallCount = 0
    var checkScreenRecordingCallCount = 0
    var requestScreenRecordingCallCount = 0

    func checkMicrophonePermission() async -> PermissionStatus {
        checkMicrophoneCallCount += 1
        return microphoneStatus
    }

    func requestMicrophonePermission() async -> PermissionStatus {
        requestMicrophoneCallCount += 1
        return microphoneStatus
    }

    func checkSpeechRecognitionPermission() async -> PermissionStatus {
        checkSpeechRecognitionCallCount += 1
        return speechRecognitionStatus
    }

    func requestSpeechRecognitionPermission() async -> PermissionStatus {
        requestSpeechRecognitionCallCount += 1
        return speechRecognitionStatus
    }

    func checkScreenRecordingPermission() async -> PermissionStatus {
        checkScreenRecordingCallCount += 1
        return screenRecordingStatus
    }

    func requestScreenRecordingPermission() async -> PermissionStatus {
        requestScreenRecordingCallCount += 1
        return screenRecordingStatus
    }

    func checkAllTranscriptionPermissions() async -> Bool {
        microphoneStatus.isGranted && speechRecognitionStatus.isGranted && screenRecordingStatus.isGranted
    }
}
