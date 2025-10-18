//
//  TranscriptionViewModelTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Testing

@testable import LiveAssistant

/// Tests for TranscriptionViewModel.
@Suite
struct TranscriptionViewModelTests {
    // MARK: - Permission Tests

    @Test
    @MainActor
    func testCheckPermissions() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        mockPermissionService.microphoneStatus = .authorized
        mockPermissionService.speechRecognitionStatus = .authorized
        mockPermissionService.screenRecordingStatus = .authorized

        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        // Act
        await vm.checkPermissions()

        // Assert
        #expect(vm.permissionsGranted == true)
        #expect(vm.microphonePermissionStatus == .authorized)
        #expect(vm.speechRecognitionPermissionStatus == .authorized)
        #expect(vm.screenRecordingPermissionStatus == .authorized)
        #expect(mockPermissionService.checkMicrophoneCallCount == 1)
        #expect(mockPermissionService.checkSpeechRecognitionCallCount == 1)
        #expect(mockPermissionService.checkScreenRecordingCallCount == 1)
    }

    @Test
    @MainActor
    func checkPermissionsDenied() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        mockPermissionService.microphoneStatus = .denied
        mockPermissionService.speechRecognitionStatus = .authorized
        mockPermissionService.screenRecordingStatus = .authorized

        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        // Act
        await vm.checkPermissions()

        // Assert
        #expect(vm.permissionsGranted == false)
        #expect(vm.microphonePermissionStatus == .denied)
    }

    @Test
    @MainActor
    func testRequestPermissions() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        mockPermissionService.microphoneStatus = .authorized
        mockPermissionService.speechRecognitionStatus = .authorized
        mockPermissionService.screenRecordingStatus = .authorized

        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        // Act
        await vm.requestPermissions()

        // Assert
        #expect(vm.permissionsGranted == true)
        #expect(mockPermissionService.requestMicrophoneCallCount == 1)
        #expect(mockPermissionService.requestSpeechRecognitionCallCount == 1)
        #expect(mockPermissionService.requestScreenRecordingCallCount == 1)
    }

    // MARK: - Recording Tests

    @Test
    @MainActor
    func startRecordingWithoutPermissions() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        mockPermissionService.microphoneStatus = .denied
        mockPermissionService.speechRecognitionStatus = .authorized
        mockPermissionService.screenRecordingStatus = .authorized

        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        // Act
        await vm.start()

        // Assert
        #expect(vm.isRecording == false)
        #expect(vm.error != nil)
        #expect(mockRepository.startMicrophoneCallCount == 0)
    }

    @Test
    @MainActor
    func startRecordingWithPermissions() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        mockPermissionService.microphoneStatus = .authorized
        mockPermissionService.speechRecognitionStatus = .authorized
        mockPermissionService.screenRecordingStatus = .authorized

        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        await vm.checkPermissions()

        // Act
        await vm.start()

        // Small delay to allow async operations
        try? await Task.sleep(for: .milliseconds(100))

        // Assert
        #expect(vm.isRecording == true)
        #expect(vm.isMicrophoneEnabled == true)
        #expect(vm.error == nil)
    }

    @Test
    @MainActor
    func stopRecording() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        mockPermissionService.microphoneStatus = .authorized
        mockPermissionService.speechRecognitionStatus = .authorized
        mockPermissionService.screenRecordingStatus = .authorized

        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        await vm.checkPermissions()
        await vm.start()

        // Act
        await vm.stop()

        // Assert
        #expect(vm.isRecording == false)
        #expect(vm.isMicrophoneEnabled == false)
        #expect(vm.isSystemAudioEnabled == false)
        #expect(mockRepository.stopAllCallCount == 1)
    }

    // MARK: - Toggle Tests

    @Test
    @MainActor
    func testToggleMicrophone() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        // Act - Enable
        await vm.toggleMicrophone()

        // Assert - Enabled
        #expect(vm.isMicrophoneEnabled == true)
        #expect(mockRepository.startMicrophoneCallCount == 1)

        // Act - Disable
        await vm.toggleMicrophone()

        // Assert - Disabled
        #expect(vm.isMicrophoneEnabled == false)
        #expect(mockRepository.stopMicrophoneCallCount == 1)
    }

    @Test
    @MainActor
    func testToggleSystemAudio() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        // Act - Enable
        await vm.toggleSystemAudio()

        // Assert - Enabled
        #expect(vm.isSystemAudioEnabled == true)
        #expect(mockRepository.startSystemAudioCallCount == 1)

        // Act - Disable
        await vm.toggleSystemAudio()

        // Assert - Disabled
        #expect(vm.isSystemAudioEnabled == false)
        #expect(mockRepository.stopSystemAudioCallCount == 1)
    }

    // MARK: - Segment Handling Tests

    @Test
    @MainActor
    func segmentReceiving() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        mockPermissionService.microphoneStatus = .authorized
        mockPermissionService.speechRecognitionStatus = .authorized
        mockPermissionService.screenRecordingStatus = .authorized

        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        await vm.checkPermissions()
        await vm.start()

        // Wait for stream to be set up
        try? await Task.sleep(for: .milliseconds(100))

        // Act
        let segment = TranscriptionSegment(
            text: "Hello world",
            startTime: 0.0,
            endTime: 1.0,
            confidence: 0.95,
            isFinal: true,
            speaker: .microphone
        )
        mockRepository.emitSegment(segment)

        // Wait for segment to be processed
        try? await Task.sleep(for: .milliseconds(100))

        // Assert
        #expect(vm.segments.count == 1)
        #expect(vm.segments.first?.text == "Hello world")
    }

    @Test
    @MainActor
    func clearSegments() async throws {
        // Arrange
        let mockPermissionService = MockPermissionService()
        let mockRepository = MockTranscriptionRepository()
        let vm = TranscriptionViewModel(
            transcriptionRepository: mockRepository,
            permissionService: mockPermissionService
        )

        // Add some segments manually for testing
        let segment = TranscriptionSegment(
            text: "Test",
            startTime: 0.0,
            endTime: 1.0,
            confidence: 0.9,
            isFinal: true,
            speaker: .microphone
        )
        await vm.start()
        try? await Task.sleep(for: .milliseconds(100))
        mockRepository.emitSegment(segment)
        try? await Task.sleep(for: .milliseconds(100))

        // Act
        await vm.clear()

        // Assert
        #expect(vm.segments.isEmpty)
        #expect(mockRepository.clearSessionCallCount == 1)
    }
}
