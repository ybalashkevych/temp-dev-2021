//
//  PermissionService.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import AVFoundation
import Foundation
import ScreenCaptureKit
import Speech

/// Service for managing application permissions including microphone, speech recognition, and screen recording.
final class PermissionService: PermissionServiceProtocol {
    func checkMicrophonePermission() async -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }

    func requestMicrophonePermission() async -> PermissionStatus {
        print("🎤 PermissionService: Checking current microphone status...")
        let currentStatus = await checkMicrophonePermission()
        print("🎤 PermissionService: Current status = \(currentStatus)")

        if currentStatus != .notDetermined {
            print("🎤 PermissionService: Status already determined, returning \(currentStatus)")
            return currentStatus
        }

        print("🎤 PermissionService: Requesting microphone access from system...")
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        print("🎤 PermissionService: System returned granted = \(granted)")
        return granted ? .authorized : .denied
    }

    func checkSpeechRecognitionPermission() async -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }

    func requestSpeechRecognitionPermission() async -> PermissionStatus {
        let currentStatus = await checkSpeechRecognitionPermission()

        if currentStatus != .notDetermined {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let permissionStatus: PermissionStatus
                switch status {
                case .authorized:
                    permissionStatus = .authorized
                case .denied:
                    permissionStatus = .denied
                case .notDetermined:
                    permissionStatus = .notDetermined
                case .restricted:
                    permissionStatus = .restricted
                @unknown default:
                    permissionStatus = .notDetermined
                }
                continuation.resume(returning: permissionStatus)
            }
        }
    }

    func checkScreenRecordingPermission() async -> PermissionStatus {
        // Check if we can get shareable content (indicates screen recording permission)
        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            // If we can get content, permission is granted
            return availableContent.displays.isEmpty ? .denied : .authorized
        } catch {
            // If we can't get content, permission is likely not granted
            return .denied
        }
    }

    func requestScreenRecordingPermission() async -> PermissionStatus {
        // For screen recording, we need to trigger the permission prompt by attempting to capture
        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            // If successful, permission is granted
            return availableContent.displays.isEmpty ? .denied : .authorized
        } catch {
            // If it fails, we need to guide the user to System Settings
            return .denied
        }
    }

    func checkAllTranscriptionPermissions() async -> Bool {
        let micStatus = await checkMicrophonePermission()
        let speechStatus = await checkSpeechRecognitionPermission()
        let screenStatus = await checkScreenRecordingPermission()

        return micStatus.isGranted && speechStatus.isGranted && screenStatus.isGranted
    }
}
