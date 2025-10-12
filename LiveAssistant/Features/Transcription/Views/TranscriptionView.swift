//
//  TranscriptionView.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import SwiftUI
import Swinject

/// Main view for displaying and controlling real-time transcription.
struct TranscriptionView: View {
    @State private var vm: TranscriptionViewModel

    init(vm: TranscriptionViewModel? = AppComponent.shared.container.resolve(TranscriptionViewModel.self)) {
        guard let vm = vm else {
            fatalError("TranscriptionViewModel not registered in DI container")
        }
        self.vm = vm
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            RecordingControlsView(
                isRecording: vm.isRecording,
                isMicrophoneEnabled: vm.isMicrophoneEnabled,
                isSystemAudioEnabled: vm.isSystemAudioEnabled,
                onStart: {
                    await vm.start()
                },
                onStop: {
                    await vm.stop()
                },
                onToggleMicrophone: {
                    await vm.toggleMicrophone()
                },
                onToggleSystemAudio: {
                    await vm.toggleSystemAudio()
                },
                onClear: {
                    await vm.clear()
                }
            )
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Error banner
            if let error = vm.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(Strings.Ui.dismiss) {
                        vm.dismissError()
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))

                Divider()
            }

            // Permission request view
            if !vm.permissionsGranted {
                PermissionRequestView(
                    microphoneStatus: vm.microphonePermissionStatus,
                    speechRecognitionStatus: vm.speechRecognitionPermissionStatus,
                    screenRecordingStatus: vm.screenRecordingPermissionStatus,
                    isChecking: vm.isCheckingPermissions
                ) {
                    await vm.requestPermissions()
                }
                .padding()
            } else {
                // Transcription segments list
                if vm.segments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No transcription yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Start recording to see transcription")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(vm.segments) { segment in
                                    TranscriptionSegmentRow(segment: segment)
                                        .id(segment.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: vm.segments.count) { _, _ in
                            if let lastSegment = vm.segments.last {
                                withAnimation {
                                    proxy.scrollTo(lastSegment.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            await vm.checkPermissions()
        }
    }
}
