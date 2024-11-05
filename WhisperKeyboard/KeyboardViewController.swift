//
//  KeyboardViewController.swift
//  WhisperKeybard
//
//  Created by Aman Kishore on 10/27/24.
//
import UIKit
import AVFoundation
import WhisperKit
import Speech
class KeyboardViewController: UIInputViewController {
    private var transcriptionManager = TranscriptionManager()
    private var isRecording = false
    private let sharedDefaults = UserDefaults(suiteName: "group.com.amanml.whisperkeyboard")
    
    private lazy var micButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "mic"), for: .normal)
        button.addTarget(self, action: #selector(micButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .systemBlue
        return button
    }()
    
    private lazy var insertTranscriptionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Insert Transcription", for: .normal)
        button.addTarget(self, action: #selector(insertTranscriptionTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .systemBlue
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add debug print
        print("DEBUG: Keyboard view did load")
        
        // Setup the microphone button
        setupDictationButton()
        setupTranscriptionObserver()
        setupInsertTranscriptionButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("DEBUG: Keyboard view will appear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("DEBUG: Keyboard view did appear")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("DEBUG: Keyboard view will disappear")
    }
    
    private func setupDictationButton() {
        view.addSubview(micButton)
        
        // Add a background color to the view to make it visible
        view.backgroundColor = .systemBackground
        
        // Position the mic button in the center of the keyboard
        NSLayoutConstraint.activate([
            micButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 44),
            micButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Make the button larger and more visible
        micButton.layer.cornerRadius = 22
        micButton.tintColor = .white
        updateMicButtonAppearance()
    }
    
    private func updateMicButtonAppearance() {
        let imageName = isRecording ? "waveform" : "mic"
        micButton.setImage(UIImage(systemName: imageName), for: .normal)
        micButton.backgroundColor = isRecording ? .systemRed : .systemBlue
    }
    
    @objc private func micButtonTapped() {
        print("DEBUG: Mic button tapped")
        
        // Toggle recording state
        isRecording = true
        updateMicButtonAppearance()
                
        // Use UIApplication openURL via UIPasteboard
        let urlString = "whisperkey://record"
        UIPasteboard.general.string = urlString
        
        // Post notification to containing app
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenWhisperKeyURL"),
            object: urlString
        )
        
        // Reset button after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.isRecording = false
            self?.updateMicButtonAppearance()
        }
    }
    
    private func handleRecordingStop() {
        SharedAudioRecorder.shared.stopRecording()
        isRecording = false
        processRecordedAudio()
    }
    
    private func processRecordedAudio() {
        print("DEBUG: Processing recorded audio")
        if let audioData = sharedDefaults?.data(forKey: "recordedAudio") {
            print("DEBUG: Retrieved audio data of size: \(audioData.count) bytes")
            processAudioData(audioData)
        } else {
            print("DEBUG: No audio data found in UserDefaults")
        }
    }
    
    private func processAudioData(_ data: Data) {
        let buffer = [Float](unsafeUninitializedCapacity: data.count / MemoryLayout<Float>.size) { buffer, initializedCount in
            data.copyBytes(to: buffer, count: data.count)
            initializedCount = data.count / MemoryLayout<Float>.size
        }
        
        Task {
            await transcriptionManager.transcribe(audioData: buffer)
            self.handleTranscribedText(transcriptionManager.transcribedText)
            sharedDefaults?.removeObject(forKey: "recordedAudio")
        }
    }
    
    private func handleTranscribedText(_ text: String) {
        print("text: \(text)")
        self.textDocumentProxy.insertText(text)
        sharedDefaults?.set(text, forKey: "latestTranscription")
    }
    
    private func setupTranscriptionObserver() {
        NotificationCenter.default.addObserver(
            forName: .transcriptionComplete,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let text = notification.object as? String {
                self?.textDocumentProxy.insertText(text)
            }
        }
    }
    
    private func setupURLObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ReceivedURL"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let url = notification.object as? URL {
                print("DEBUG: URL received via notification: \(url)")
                self?.handleIncomingURL(url)
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("DEBUG: Processing URL in ContentView: \(url)")
        print("DEBUG: URL components - scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil"), path: \(url.path)")
        if let audioData = sharedDefaults?.data(forKey: "recordedAudio") {
            if url.scheme == "whisperkey" {
                print("DEBUG: Correct URL scheme")
                if url.host == "record" {
                    print("DEBUG: Starting recording from URL scheme")
                    SharedAudioRecorder.shared.startRecording()
                    isRecording = true
                    
                    // Automatically stop recording after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        if self?.isRecording == true {
                            print("DEBUG: Auto-stopping recording after 5 seconds")
                            self?.handleRecordingStop()
                        }
                    }
                } else {
                    print("DEBUG: Invalid host: \(url.host ?? "nil")")
                }
            }
        }
    }
    
    private func setupInsertTranscriptionButton() {
        view.addSubview(insertTranscriptionButton)
        
        NSLayoutConstraint.activate([
            insertTranscriptionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            insertTranscriptionButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            insertTranscriptionButton.widthAnchor.constraint(equalToConstant: 200),
            insertTranscriptionButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func insertTranscriptionTapped() {
        if let transcription = sharedDefaults?.string(forKey: "latestTranscription") {
            self.textDocumentProxy.insertText(transcription)
            // Optionally clear the transcription after insertion
            sharedDefaults?.removeObject(forKey: "latestTranscription")
        } else {
            // Provide feedback if no transcription is available
            print("No transcription available")
        }
    }
}
