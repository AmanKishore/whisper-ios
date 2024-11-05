//
//  SharedAudioRecorder.swift
//  whisper-ios
//
//  Created by Aman Kishore on 11/3/24.
//

import Foundation
import AVFoundation

class SharedAudioRecorder: NSObject, AVAudioRecorderDelegate {
    static let shared = SharedAudioRecorder()
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder?
    private let sharedDefaults = UserDefaults(suiteName: "group.com.amanml.whisper")
    
    var isRecording = false
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("DEBUG: Audio session set up successfully")
            
            // Request microphone permission
            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    print("DEBUG: Microphone permission granted: \(granted)")
                    if !granted {
                        print("DEBUG: Microphone permission denied")
                    }
                }
            }
        } catch {
            print("DEBUG: Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        print("DEBUG: startRecording method called")
        guard !isRecording else {
            print("DEBUG: Already recording")
            return
        }
        
        print("DEBUG: Starting recording...")
        
        // Define the recording settings for Linear PCM
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Create a temporary file URL for the recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            print("DEBUG: Recording started at \(fileURL)")
        } catch {
            print("DEBUG: Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard isRecording, let recorder = audioRecorder else {
            print("DEBUG: Not recording or recorder is nil")
            return
        }
        
        recorder.stop()
        isRecording = false
        print("DEBUG: Recording stopped")
        
        // The delegate method will handle processing
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            do {
                let audioData = try Data(contentsOf: recorder.url)
                print("DEBUG: Saved audio data of size: \(audioData.count) bytes")
                
                // Notify interested parties that audio is ready
                NotificationCenter.default.post(name: .recordingDidFinish, object: audioData)
                
                // Optionally, remove the temporary file
                try FileManager.default.removeItem(at: recorder.url)
                print("DEBUG: Temporary recording file removed")
            } catch {
                print("DEBUG: Failed to process audio data: \(error.localizedDescription)")
            }
        } else {
            print("DEBUG: Recording was not successful")
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let recordingDidFinish = Notification.Name("recordingDidFinish")
}
