import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine
@MainActor
final class SpeechService: NSObject, ObservableObject {
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var audioLevel: CGFloat = 0
    
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
        requestPermissions()
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if !granted { print("Microphone permission denied") }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted { print("Microphone permission denied") }
            }
        }
    }
    
    func startRecording() {
        if isRecording { return }
        
        Task { @MainActor in
            self.transcript = ""
            self.audioLevel = 0
            self.isRecording = true
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed:", error)
            Task { @MainActor in self.isRecording = false }
            return
        }
        
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        self.request = newRequest
        
        task?.cancel()
        task = nil
        
        task = recognizer?.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self else { return }
            
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcript = text
                }
            }
            
            if error != nil {
                self.stopRecording()
            }
        }
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.request?.append(buffer)
            
            let level = buffer.normalizedRMS()
            Task { @MainActor in
                self.audioLevel = level
            }
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start failed:", error)
            stopRecording()
        }
    }
    
    func stopRecording() {
        if !isRecording && request == nil && task == nil { return }
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        task?.cancel()
        task = nil
        
        request?.endAudio()
        request = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session deactivate failed:", error)
        }
        
        Task { @MainActor in
            self.isRecording = false
            self.audioLevel = 0
        }
    }
}

extension AVAudioPCMBuffer {
    func normalizedRMS() -> CGFloat {
        guard let channelData = floatChannelData?[0] else { return 0 }
        let frameLength = Int(self.frameLength)
        if frameLength == 0 { return 0 }
        
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        
        let scaled = min(max(CGFloat(rms) * 8, 0), 1)
        return scaled
    }
}
