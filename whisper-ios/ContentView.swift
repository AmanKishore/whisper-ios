//
//  ContentView.swift
//  whisper-ios
//
//  Created by Aman Kishore on 10/20/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var transcriptionManager = TranscriptionManager()
    @State private var isRecording = false
    private let sharedDefaults = UserDefaults(suiteName: "group.com.amanml.whisper")
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isRecording ? "waveform" : "mic")
                .imageScale(.large)
                .foregroundColor(isRecording ? .red : .blue)
                .padding()
            
            Text(isRecording ? "Recording..." : "Tap to Record")
                .font(.headline)
            
            Button(action: {
                if isRecording {
                    handleRecordingStop()
                } else {
                    SharedAudioRecorder.shared.startRecording()
                    isRecording = true
                }
            }) {
                Text(isRecording ? "Stop" : "Start")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(transcriptionManager.isLoading)
            
            if transcriptionManager.isLoading {
                ProgressView("Processing...")
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Transcription:")
                    .font(.headline)
                
                ScrollView {
                    Text(transcriptionManager.transcribedText)
                        .padding()
                        .frame(minHeight: 100)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            
            if let errorMessage = transcriptionManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .onAppear {
            print("DEBUG: ContentView appeared")
            setupURLObserver()
            
            // Check for any existing audio data on appear
            if let audioData = sharedDefaults?.data(forKey: "recordedAudio") {
                print("DEBUG: Found existing audio data on appear")
                let buffer = [Float](unsafeUninitializedCapacity: audioData.count / MemoryLayout<Float>.size) { buffer, initializedCount in
                    audioData.copyBytes(to: buffer, count: audioData.count)
                    initializedCount = audioData.count / MemoryLayout<Float>.size
                }
                
                Task {
                    await transcriptionManager.transcribe(audioData: buffer)
                    sharedDefaults?.removeObject(forKey: "recordedAudio")
                }
            }
        }
        .onOpenURL { url in
            print("DEBUG: Direct URL received in ContentView: \(url)")
            handleIncomingURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptionComplete)) { notification in
            if let transcribedText = notification.object as? String {
                print("DEBUG: Received transcribed text via notification: \(transcribedText)")
                // Optionally perform additional actions with the transcribedText
            }
        }
    }
    
    private func setupURLObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ReceivedURL"),
            object: nil,
            queue: .main
        ) { [self] notification in
            if let url = notification.object as? URL,
               url.scheme == "whisperkey",
               url.host == "record" {
                print("DEBUG: Starting recording from URL scheme")
                SharedAudioRecorder.shared.startRecording()
                isRecording = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenWhisperKeyURL"),
            object: nil,
            queue: .main
        ) { [self] notification in
            if let urlString = notification.object as? String,
               let url = URL(string: urlString) {
                SharedAudioRecorder.shared.startRecording()
                isRecording = true
                
                // Auto-stop recording after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if isRecording {
                        handleRecordingStop()
                    }
                }
            }
        }
        
        // Check for any existing audio data
        if let audioData = sharedDefaults?.data(forKey: "recordedAudio") {
            print("DEBUG: Found existing audio data")
            processAudioData(audioData)
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("DEBUG: Processing URL in ContentView: \(url)")
        print("DEBUG: URL components - scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil"), path: \(url.path)")
        
        if url.scheme == "whisperkey" {
            print("DEBUG: Correct URL scheme")
            if url.host == "record" {
                print("DEBUG: Starting recording from URL scheme")
                SharedAudioRecorder.shared.startRecording()
                isRecording = true
                
                // Automatically stop recording after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if isRecording {
                        print("DEBUG: Auto-stopping recording after 5 seconds")
                        handleRecordingStop()
                    }
                }
            } else {
                print("DEBUG: Invalid host: \(url.host ?? "nil")")
            }
        } else {
            print("DEBUG: Invalid scheme: \(url.scheme ?? "nil")")
        }
    }
    
    private func handleRecordingStop() {
        SharedAudioRecorder.shared.stopRecording()
        isRecording = false
    }
    
    private func processAudioData(_ audioData: Data) {
        print("DEBUG: Processing audio data")
        let buffer = [Float](unsafeUninitializedCapacity: audioData.count / MemoryLayout<Float>.size) { buffer, initializedCount in
            audioData.copyBytes(to: buffer, count: audioData.count)
            initializedCount = audioData.count / MemoryLayout<Float>.size
        }
        
        Task {
            await transcriptionManager.transcribe(audioData: buffer)
            sharedDefaults?.removeObject(forKey: "recordedAudio")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
