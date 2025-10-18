//
//  PermissionServiceTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Testing

@testable import LiveAssistant

/// Tests for PermissionService demonstrating service testing with system permissions.
@Suite
struct PermissionServiceTests {
    
    // MARK: - Test Setup
    
    private func createService() -> PermissionService {
        PermissionService()
    }
    
    // MARK: - Microphone Permission Tests
    
    @Test
    func checkMicrophonePermission() async {
        // Arrange
        let service = createService()
        
        // Act
        let status = await service.checkMicrophonePermission()
        
        // Assert - Status should be one of the valid values
        #expect([PermissionStatus.authorized, .denied, .notDetermined, .restricted].contains(status))
    }
    
    @Test
    func requestMicrophonePermission() async {
        // Arrange
        let service = createService()
        
        // Act
        let status = await service.requestMicrophonePermission()
        
        // Assert - Status should be one of the valid values
        #expect([PermissionStatus.authorized, .denied, .notDetermined, .restricted].contains(status))
    }
    
    // MARK: - Speech Recognition Permission Tests
    
    @Test
    func checkSpeechRecognitionPermission() async {
        // Arrange
        let service = createService()
        
        // Act
        let status = await service.checkSpeechRecognitionPermission()
        
        // Assert - Status should be one of the valid values
        #expect([PermissionStatus.authorized, .denied, .notDetermined, .restricted].contains(status))
    }
    
    @Test
    func requestSpeechRecognitionPermission() async {
        // Arrange
        let service = createService()
        
        // Act
        let status = await service.requestSpeechRecognitionPermission()
        
        // Assert - Status should be one of the valid values
        #expect([PermissionStatus.authorized, .denied, .notDetermined, .restricted].contains(status))
    }
    
    // MARK: - Screen Recording Permission Tests
    
    @Test
    func checkScreenRecordingPermission() async {
        // Arrange
        let service = createService()
        
        // Act
        let status = await service.checkScreenRecordingPermission()
        
        // Assert - Status should be one of the valid values
        #expect([PermissionStatus.authorized, .denied, .notDetermined, .restricted].contains(status))
    }
    
    @Test
    func requestScreenRecordingPermission() async {
        // Arrange
        let service = createService()
        
        // Act
        let status = await service.requestScreenRecordingPermission()
        
        // Assert - Status should be one of the valid values
        #expect([PermissionStatus.authorized, .denied, .notDetermined, .restricted].contains(status))
    }
    
    // MARK: - Permission Status Tests
    
    @Test
    func permissionStatusIsGranted() {
        // Arrange
        let authorized = PermissionStatus.authorized
        
        // Assert
        #expect(authorized.isGranted == true)
    }
    
    @Test
    func permissionStatusIsNotGranted() {
        // Arrange
        let denied = PermissionStatus.denied
        let notDetermined = PermissionStatus.notDetermined
        let restricted = PermissionStatus.restricted
        
        // Assert
        #expect(denied.isGranted == false)
        #expect(notDetermined.isGranted == false)
        #expect(restricted.isGranted == false)
    }
    
    // MARK: - Permission Status Description Tests
    
    @Test
    func permissionStatusDescriptions() {
        // Arrange & Assert
        #expect(PermissionStatus.authorized.description == "Authorized")
        #expect(PermissionStatus.denied.description == "Denied")
        #expect(PermissionStatus.notDetermined.description == "Not Determined")
        #expect(PermissionStatus.restricted.description == "Restricted")
    }
    
    // MARK: - Permission Status Equality Tests
    
    @Test
    func permissionStatusEquality() {
        // Arrange
        let status1 = PermissionStatus.authorized
        let status2 = PermissionStatus.authorized
        let status3 = PermissionStatus.denied
        
        // Assert
        #expect(status1 == status2)
        #expect(status1 != status3)
    }
    
    // MARK: - Permission Status Hashable Tests
    
    @Test
    func permissionStatusHashable() {
        // Arrange
        let status1 = PermissionStatus.authorized
        let status2 = PermissionStatus.authorized
        let status3 = PermissionStatus.denied
        
        // Act
        let set: Set<PermissionStatus> = [status1, status2, status3]
        
        // Assert
        #expect(set.count == 2) // status1 and status2 are equal, so only 2 unique values
        #expect(set.contains(.authorized))
        #expect(set.contains(.denied))
    }
    
    // MARK: - Permission Status Codable Tests
    
    @Test
    func permissionStatusCodable() throws {
        // Arrange
        let originalStatus = PermissionStatus.authorized
        
        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalStatus)
        
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(PermissionStatus.self, from: data)
        
        // Assert
        #expect(originalStatus == decodedStatus)
    }
    
    // MARK: - All Permission Statuses Test
    
    @Test
    func allPermissionStatuses() {
        // Arrange
        let allStatuses = PermissionStatus.allCases
        
        // Assert
        #expect(allStatuses.count == 4)
        #expect(allStatuses.contains(.authorized))
        #expect(allStatuses.contains(.denied))
        #expect(allStatuses.contains(.notDetermined))
        #expect(allStatuses.contains(.restricted))
    }
    
    // MARK: - Permission Status Raw Values Test
    
    @Test
    func permissionStatusRawValues() {
        // Arrange & Assert
        #expect(PermissionStatus.authorized.rawValue == "authorized")
        #expect(PermissionStatus.denied.rawValue == "denied")
        #expect(PermissionStatus.notDetermined.rawValue == "notDetermined")
        #expect(PermissionStatus.restricted.rawValue == "restricted")
    }
    
    // MARK: - Permission Status Initialization Test
    
    @Test
    func permissionStatusInitialization() {
        // Arrange & Act
        let authorized = PermissionStatus(rawValue: "authorized")
        let denied = PermissionStatus(rawValue: "denied")
        let notDetermined = PermissionStatus(rawValue: "notDetermined")
        let restricted = PermissionStatus(rawValue: "restricted")
        let invalid = PermissionStatus(rawValue: "invalid")
        
        // Assert
        #expect(authorized == .authorized)
        #expect(denied == .denied)
        #expect(notDetermined == .notDetermined)
        #expect(restricted == .restricted)
        #expect(invalid == nil)
    }
}