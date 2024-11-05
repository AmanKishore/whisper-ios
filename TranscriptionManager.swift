import Foundation
import WhisperKit
import AVFoundation

@MainActor
class TranscriptionManager: ObservableObject {
    @Published var transcribedText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var whisperPipe: WhisperKit?
    
    init() {
        Task {
            await initializeWhisperKit()
        }
        
        // Listen for recording finish notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleRecordingDidFinish(_:)), name: .recordingDidFinish, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .recordingDidFinish, object: nil)
    }
    
    private func initializeWhisperKit() async {
        guard whisperPipe == nil else { return }
        
        isLoading = true
        do {
            guard let resourcePath = Bundle.main.resourcePath else {
                throw NSError(domain: "TranscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resource path not found"])
            }
            
            let modelPath = (resourcePath as NSString).appendingPathComponent("openai_whisper-tiny")
            whisperPipe = try await WhisperKit(
                modelFolder: modelPath,
                logLevel: .error,
                prewarm: true,
                download: false
            )
            
            isLoading = false
            print("DEBUG: WhisperKit initialized successfully at path: \(modelPath)")
        } catch {
            errorMessage = "Failed to initialize WhisperKit: \(error.localizedDescription)"
            isLoading = false
            print("DEBUG: \(errorMessage ?? "Unknown error")")
        }
    }
    
    @objc private func handleRecordingDidFinish(_ notification: Notification) {
        print("DEBUG: handleRecordingDidFinish called")
        if let audioData = notification.object as? Data {
            print("DEBUG: Received audio data of size: \(audioData.count) bytes")
            processAudioData(audioData)
        } else {
            print("DEBUG: Invalid audio data received in notification")
        }
    }
    
    private func processAudioData(_ data: Data) {
        // Decode the WAV file into [Float]
        guard let audioBuffer = decodeWAV(data: data) else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to decode audio data"
                self.isLoading = false
            }
            return
        }
        
        Task {
            await transcribe(audioData: audioBuffer)
        }
    }
    
    private func decodeWAV(data: Data) -> [Float]? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("temp_decoding.wav")
        
        do {
            try data.write(to: tempFileURL)
            let audioFile = try AVAudioFile(forReading: tempFileURL)
            let format = audioFile.processingFormat
            let frameCount = UInt32(audioFile.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("DEBUG: Failed to create AVAudioPCMBuffer")
                return nil
            }
            
            try audioFile.read(into: buffer)
            try FileManager.default.removeItem(at: tempFileURL)
            
            guard let floatChannelData = buffer.floatChannelData else {
                print("DEBUG: No float channel data available")
                return nil
            }
            
            let channelData = floatChannelData.pointee
            let frameLength = Int(buffer.frameLength)
            let floatArray = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
            return floatArray
        } catch {
            print("DEBUG: Error decoding WAV data: \(error.localizedDescription)")
            return nil
        }
    }
    
    func transcribe(audioData: [Float]) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.transcribedText = ""
        }
        
        do {
            print("DEBUG: Starting transcription process")
            guard let whisperPipe = whisperPipe else {
                throw NSError(domain: "TranscriptionManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "WhisperKit not initialized"])
            }
            
            let results = try await whisperPipe.transcribe(audioArray: audioData)
            guard let firstResult = results.first else {
                throw NSError(domain: "TranscriptionManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "No transcription result"])
            }
            
            self.transcribedText = firstResult.text
            self.isLoading = false
            print("DEBUG: Transcription successful: \(self.transcribedText)")
            
            // Post notification if needed
            NotificationCenter.default.post(name: .transcriptionComplete, object: self.transcribedText)
        } catch {
            self.errorMessage = "Transcription failed: \(error.localizedDescription)"
            self.isLoading = false
            print("DEBUG: \(self.errorMessage ?? "Unknown error")")
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let transcriptionComplete = Notification.Name("transcriptionComplete")
}
