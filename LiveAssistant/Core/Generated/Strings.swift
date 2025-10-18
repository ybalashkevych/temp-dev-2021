// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum Strings {
  public enum App {
    public enum Tab {
      /// Demo Items
      public static let demoItems = Strings.tr("Localizable", "app.tab.demo_items", fallback: "Demo Items")
      /// Transcription
      public static let transcription = Strings.tr("Localizable", "app.tab.transcription", fallback: "Transcription")
    }
  }
  public enum Chat {
    /// No messages yet
    public static let emptyState = Strings.tr("Localizable", "chat.empty_state", fallback: "No messages yet")
    /// Send
    public static let send = Strings.tr("Localizable", "chat.send", fallback: "Send")
    public enum Error {
      /// Received an invalid response from the server.
      public static let invalidResponse = Strings.tr("Localizable", "chat.error.invalid_response", fallback: "Received an invalid response from the server.")
      /// Localizable.strings
      ///   LiveAssistant
      /// 
      ///   Created by Yurii Balashkevych on 12/10/2025.
      ///   Copyright © 2025. All rights reserved.
      public static let networkFailure = Strings.tr("Localizable", "chat.error.network_failure", fallback: "Network connection failed. Please check your internet connection.")
      /// You are not authorized to perform this action.
      public static let unauthorized = Strings.tr("Localizable", "chat.error.unauthorized", fallback: "You are not authorized to perform this action.")
    }
    public enum Placeholder {
      /// Type a message...
      public static let message = Strings.tr("Localizable", "chat.placeholder.message", fallback: "Type a message...")
    }
  }
  public enum Error {
    /// An unexpected error occurred. Please try again.
    public static let generic = Strings.tr("Localizable", "error.generic", fallback: "An unexpected error occurred. Please try again.")
    /// An unknown error occurred.
    public static let unknown = Strings.tr("Localizable", "error.unknown", fallback: "An unknown error occurred.")
    public enum Repository {
      /// Failed to delete data
      public static let deleteFailed = Strings.tr("Localizable", "error.repository.delete_failed", fallback: "Failed to delete data")
      /// Failed to fetch data
      public static let fetchFailed = Strings.tr("Localizable", "error.repository.fetch_failed", fallback: "Failed to fetch data")
      /// Data not found
      public static let notFound = Strings.tr("Localizable", "error.repository.not_found", fallback: "Data not found")
      /// Failed to save data
      public static let saveFailed = Strings.tr("Localizable", "error.repository.save_failed", fallback: "Failed to save data")
    }
  }
  public enum Permissions {
    /// All permissions granted!
    public static let allGranted = Strings.tr("Localizable", "permissions.all_granted", fallback: "All permissions granted!")
    /// Checking...
    public static let checking = Strings.tr("Localizable", "permissions.checking", fallback: "Checking...")
    /// LiveAssistant needs the following permissions to provide real-time transcription:
    public static let description = Strings.tr("Localizable", "permissions.description", fallback: "LiveAssistant needs the following permissions to provide real-time transcription:")
    /// Grant Permissions
    public static let grantButton = Strings.tr("Localizable", "permissions.grant_button", fallback: "Grant Permissions")
    /// Permissions Required
    public static let title = Strings.tr("Localizable", "permissions.title", fallback: "Permissions Required")
    public enum Microphone {
      /// To transcribe your voice
      public static let description = Strings.tr("Localizable", "permissions.microphone.description", fallback: "To transcribe your voice")
      /// Microphone Access
      public static let title = Strings.tr("Localizable", "permissions.microphone.title", fallback: "Microphone Access")
    }
    public enum ScreenRecording {
      /// To capture system audio
      public static let description = Strings.tr("Localizable", "permissions.screen_recording.description", fallback: "To capture system audio")
      /// Screen Recording
      public static let title = Strings.tr("Localizable", "permissions.screen_recording.title", fallback: "Screen Recording")
    }
    public enum SpeechRecognition {
      /// To convert speech to text
      public static let description = Strings.tr("Localizable", "permissions.speech_recognition.description", fallback: "To convert speech to text")
      /// Speech Recognition
      public static let title = Strings.tr("Localizable", "permissions.speech_recognition.title", fallback: "Speech Recognition")
    }
    public enum Status {
      /// Authorized
      public static let authorized = Strings.tr("Localizable", "permissions.status.authorized", fallback: "Authorized")
      /// Denied
      public static let denied = Strings.tr("Localizable", "permissions.status.denied", fallback: "Denied")
      /// Not Determined
      public static let notDetermined = Strings.tr("Localizable", "permissions.status.not_determined", fallback: "Not Determined")
      /// Restricted
      public static let restricted = Strings.tr("Localizable", "permissions.status.restricted", fallback: "Restricted")
    }
  }
  public enum Quality {
    /// Average Confidence
    public static let averageConfidence = Strings.tr("Localizable", "quality.average_confidence", fallback: "Average Confidence")
    /// Average Duration
    public static let averageDuration = Strings.tr("Localizable", "quality.average_duration", fallback: "Average Duration")
    /// Completion Rate
    public static let completionRate = Strings.tr("Localizable", "quality.completion_rate", fallback: "Completion Rate")
    /// Final Segments
    public static let finalSegments = Strings.tr("Localizable", "quality.final_segments", fallback: "Final Segments")
    /// Maximum Confidence
    public static let maximumConfidence = Strings.tr("Localizable", "quality.maximum_confidence", fallback: "Maximum Confidence")
    /// Minimum Confidence
    public static let minimumConfidence = Strings.tr("Localizable", "quality.minimum_confidence", fallback: "Minimum Confidence")
    /// Partial Segments
    public static let partialSegments = Strings.tr("Localizable", "quality.partial_segments", fallback: "Partial Segments")
    /// Recognition Mode
    public static let recognitionMode = Strings.tr("Localizable", "quality.recognition_mode", fallback: "Recognition Mode")
    /// Transcription Quality
    public static let title = Strings.tr("Localizable", "quality.title", fallback: "Transcription Quality")
    /// Total Duration
    public static let totalDuration = Strings.tr("Localizable", "quality.total_duration", fallback: "Total Duration")
    /// Total Segments
    public static let totalSegments = Strings.tr("Localizable", "quality.total_segments", fallback: "Total Segments")
    /// Quality metrics unavailable
    public static let unavailable = Strings.tr("Localizable", "quality.unavailable", fallback: "Quality metrics unavailable")
  }
  public enum Recognition {
    public enum Status {
      /// Cloud
      public static let cloud = Strings.tr("Localizable", "recognition.status.cloud", fallback: "Cloud")
      /// Cloud (Fallback)
      public static let cloudFallback = Strings.tr("Localizable", "recognition.status.cloud_fallback", fallback: "Cloud (Fallback)")
      /// On-Device
      public static let onDevice = Strings.tr("Localizable", "recognition.status.on_device", fallback: "On-Device")
      /// Unavailable
      public static let unavailable = Strings.tr("Localizable", "recognition.status.unavailable", fallback: "Unavailable")
    }
  }
  public enum RecognitionMode {
    /// Cloud-First
    public static let cloudFirst = Strings.tr("Localizable", "recognition_mode.cloud_first", fallback: "Cloud-First")
    /// Cloud Only
    public static let cloudOnly = Strings.tr("Localizable", "recognition_mode.cloud_only", fallback: "Cloud Only")
    /// Recognition mode determines where speech processing occurs
    public static let description = Strings.tr("Localizable", "recognition_mode.description", fallback: "Recognition mode determines where speech processing occurs")
    /// On-Device First
    public static let onDeviceFirst = Strings.tr("Localizable", "recognition_mode.on_device_first", fallback: "On-Device First")
    /// On-Device Only
    public static let onDeviceOnly = Strings.tr("Localizable", "recognition_mode.on_device_only", fallback: "On-Device Only")
    public enum CloudFirst {
      /// Uses cloud for better accuracy, falls back to on-device if needed
      public static let description = Strings.tr("Localizable", "recognition_mode.cloud_first.description", fallback: "Uses cloud for better accuracy, falls back to on-device if needed")
    }
    public enum CloudOnly {
      /// Always uses cloud processing for maximum accuracy
      public static let description = Strings.tr("Localizable", "recognition_mode.cloud_only.description", fallback: "Always uses cloud processing for maximum accuracy")
    }
    public enum OnDeviceFirst {
      /// Prioritizes privacy with on-device processing
      public static let description = Strings.tr("Localizable", "recognition_mode.on_device_first.description", fallback: "Prioritizes privacy with on-device processing")
    }
    public enum OnDeviceOnly {
      /// Always uses on-device processing for maximum privacy
      public static let description = Strings.tr("Localizable", "recognition_mode.on_device_only.description", fallback: "Always uses on-device processing for maximum privacy")
    }
  }
  public enum Settings {
    /// About
    public static let about = Strings.tr("Localizable", "settings.about", fallback: "About")
    /// Profile
    public static let profile = Strings.tr("Localizable", "settings.profile", fallback: "Profile")
    /// Settings
    public static let title = Strings.tr("Localizable", "settings.title", fallback: "Settings")
  }
  public enum Transcription {
    public enum Control {
      /// Clear
      public static let clear = Strings.tr("Localizable", "transcription.control.clear", fallback: "Clear")
      /// Microphone
      public static let microphone = Strings.tr("Localizable", "transcription.control.microphone", fallback: "Microphone")
      /// Start
      public static let start = Strings.tr("Localizable", "transcription.control.start", fallback: "Start")
      /// Stop
      public static let stop = Strings.tr("Localizable", "transcription.control.stop", fallback: "Stop")
      /// System Audio
      public static let systemAudio = Strings.tr("Localizable", "transcription.control.system_audio", fallback: "System Audio")
    }
    public enum Empty {
      /// Start recording to see transcription
      public static let message = Strings.tr("Localizable", "transcription.empty.message", fallback: "Start recording to see transcription")
      /// No transcription yet
      public static let title = Strings.tr("Localizable", "transcription.empty.title", fallback: "No transcription yet")
    }
    public enum Error {
      /// Failed to process audio.
      public static let audioProcessingFailed = Strings.tr("Localizable", "transcription.error.audio_processing_failed", fallback: "Failed to process audio.")
      /// Failed to start capture session.
      public static let captureSessionFailed = Strings.tr("Localizable", "transcription.error.capture_session_failed", fallback: "Failed to start capture session.")
      /// Failed to start audio engine.
      public static let engineStartFailed = Strings.tr("Localizable", "transcription.error.engine_start_failed", fallback: "Failed to start audio engine.")
      /// Failed to convert audio format.
      public static let formatConversionFailed = Strings.tr("Localizable", "transcription.error.format_conversion_failed", fallback: "Failed to convert audio format.")
      /// Failed to initialize transcription service.
      public static let initializationFailed = Strings.tr("Localizable", "transcription.error.initialization_failed", fallback: "Failed to initialize transcription service.")
      /// Microphone input is unavailable.
      public static let inputNodeUnavailable = Strings.tr("Localizable", "transcription.error.input_node_unavailable", fallback: "Microphone input is unavailable.")
      /// Microphone permission is required for transcription.
      public static let microphonePermission = Strings.tr("Localizable", "transcription.error.microphone_permission", fallback: "Microphone permission is required for transcription.")
      /// Speech recognition permission denied.
      public static let permissionDenied = Strings.tr("Localizable", "transcription.error.permission_denied", fallback: "Speech recognition permission denied.")
      /// Please grant all required permissions to start transcription.
      public static let permissionsRequired = Strings.tr("Localizable", "transcription.error.permissions_required", fallback: "Please grant all required permissions to start transcription.")
      /// Failed to process audio input.
      public static let processingFailed = Strings.tr("Localizable", "transcription.error.processing_failed", fallback: "Failed to process audio input.")
      /// Recognition failed: %@
      public static func recognitionFailed(_ p1: Any) -> String {
        return Strings.tr("Localizable", "transcription.error.recognition_failed", String(describing: p1), fallback: "Recognition failed: %@")
      }
      /// Speech recognizer is unavailable.
      public static let recognizerUnavailable = Strings.tr("Localizable", "transcription.error.recognizer_unavailable", fallback: "Speech recognizer is unavailable.")
      /// Failed to toggle microphone: %@
      public static func toggleMicrophone(_ p1: Any) -> String {
        return Strings.tr("Localizable", "transcription.error.toggle_microphone", String(describing: p1), fallback: "Failed to toggle microphone: %@")
      }
      /// Failed to toggle system audio: %@
      public static func toggleSystemAudio(_ p1: Any) -> String {
        return Strings.tr("Localizable", "transcription.error.toggle_system_audio", String(describing: p1), fallback: "Failed to toggle system audio: %@")
      }
    }
    public enum Segment {
      /// Confidence: %d%%
      public static func confidence(_ p1: Int) -> String {
        return Strings.tr("Localizable", "transcription.segment.confidence", p1, fallback: "Confidence: %d%%")
      }
      /// Partial
      public static let partial = Strings.tr("Localizable", "transcription.segment.partial", fallback: "Partial")
      /// Question
      public static let question = Strings.tr("Localizable", "transcription.segment.question", fallback: "Question")
    }
    public enum Speaker {
      /// Mic
      public static let microphone = Strings.tr("Localizable", "transcription.speaker.microphone", fallback: "Mic")
      /// System
      public static let system = Strings.tr("Localizable", "transcription.speaker.system", fallback: "System")
    }
    public enum Status {
      /// Recording
      public static let recording = Strings.tr("Localizable", "transcription.status.recording", fallback: "Recording")
      /// Stopped
      public static let stopped = Strings.tr("Localizable", "transcription.status.stopped", fallback: "Stopped")
    }
  }
  public enum Ui {
    /// Cancel
    public static let cancel = Strings.tr("Localizable", "ui.cancel", fallback: "Cancel")
    /// Dismiss
    public static let dismiss = Strings.tr("Localizable", "ui.dismiss", fallback: "Dismiss")
    /// Done
    public static let done = Strings.tr("Localizable", "ui.done", fallback: "Done")
    /// Loading...
    public static let loading = Strings.tr("Localizable", "ui.loading", fallback: "Loading...")
    /// Retry
    public static let retry = Strings.tr("Localizable", "ui.retry", fallback: "Retry")
    /// Save
    public static let save = Strings.tr("Localizable", "ui.save", fallback: "Save")
  }
  public enum Vocabulary {
    /// Custom Technical Terms
    public static let customTerms = Strings.tr("Localizable", "vocabulary.custom_terms", fallback: "Custom Technical Terms")
    /// %d terms loaded
    public static func termsLoaded(_ p1: Int) -> String {
      return Strings.tr("Localizable", "vocabulary.terms_loaded", p1, fallback: "%d terms loaded")
    }
    public enum Category {
      /// Cloud & Infrastructure
      public static let cloudInfrastructure = Strings.tr("Localizable", "vocabulary.category.cloud_infrastructure", fallback: "Cloud & Infrastructure")
      /// Companies & Products
      public static let companiesProducts = Strings.tr("Localizable", "vocabulary.category.companies_products", fallback: "Companies & Products")
      /// Concepts & Patterns
      public static let conceptsPatterns = Strings.tr("Localizable", "vocabulary.category.concepts_patterns", fallback: "Concepts & Patterns")
      /// Development Tools
      public static let developmentTools = Strings.tr("Localizable", "vocabulary.category.development_tools", fallback: "Development Tools")
      /// Frameworks & Libraries
      public static let frameworksLibraries = Strings.tr("Localizable", "vocabulary.category.frameworks_libraries", fallback: "Frameworks & Libraries")
      /// Programming Languages
      public static let programmingLanguages = Strings.tr("Localizable", "vocabulary.category.programming_languages", fallback: "Programming Languages")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension Strings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
