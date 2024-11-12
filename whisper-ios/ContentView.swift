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
    @State private var showCopiedAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 40) {
                    // Top microphone icon
                    Image(systemName: isRecording ? "waveform" : "mic")
                        .imageScale(.large)
                        .font(.system(size: 40))
                        .foregroundColor(isRecording ? .red : .blue)
                        .padding(.top, geometry.size.height * 0.1)
                    
                    // Recording status text
                    Text(isRecording ? "Recording..." : "")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    // Record button
                    Button(action: {
                        if isRecording {
                            handleRecordingStop()
                        } else {
                            SharedAudioRecorder.shared.startRecording()
                            isRecording = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            Text(isRecording ? "Stop Recording" : "Start Recording")
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: geometry.size.width * 0.8)
                        .background(isRecording ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .shadow(radius: 5)
                    }
                    .disabled(transcriptionManager.isLoading)
                    
                    if transcriptionManager.isLoading {
                        ProgressView("Warming Up Model...")
                            .padding()
                    }
                    
                    // Transcription section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Transcription")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            if !transcriptionManager.transcribedText.isEmpty {
                                Button(action: {
                                    UIPasteboard.general.string = transcriptionManager.transcribedText
                                    showCopiedAlert = true
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        ScrollView {
                            Text(transcriptionManager.transcribedText.isEmpty ? "No transcription yet" : transcriptionManager.transcribedText)
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                                .background(Color(.systemGray6))
                                .cornerRadius(15)
                        }
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: geometry.size.width * 0.9)
                    
                    if let errorMessage = transcriptionManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
            }
            .frame(width: geometry.size.width)
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
        .alert("Copied to clipboard", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
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
