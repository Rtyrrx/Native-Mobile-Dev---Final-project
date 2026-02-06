import SwiftUI
import SwiftData

struct CaptureView: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var speechService = SpeechService()
    private let ai = AIAnalysisService()
    
    @State private var textInput: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    HStack {
                        Text(speechService.isRecording ? "Listening…" : "Capture a moment")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                    }
                    .padding(.top, 4)
                    
                    Text(speechService.isRecording
                         ? "Talk normally. We’ll save it as a clean moment."
                         : "Voice or text. AI will clean + label it.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        Button {
                            if speechService.isRecording {
                                speechService.stopRecording()
                                if !speechService.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    textInput = speechService.transcript
                                }
                                dismissKeyboard()
                            } else {
                                dismissKeyboard()
                                speechService.startRecording()
                            }
                        } label: {
                            Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 84))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        
                        WaveformView(level: speechService.audioLevel)
                            .frame(height: 64)
                            .opacity(speechService.isRecording ? 1 : 0.35)
                            .animation(.easeInOut(duration: 0.2), value: speechService.isRecording)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Text (optional)")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Button("Done") { dismissKeyboard() }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        
                        TextEditor(text: $textInput)
                            .focused($isFocused)
                            .frame(minHeight: 140)
                            .padding(10)
                            .background(Color.black.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .onChange(of: speechService.transcript) { _, newValue in
                                if speechService.isRecording, !newValue.isEmpty {
                                    textInput = newValue
                                }
                            }
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.95))
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    Button {
                        dismissKeyboard()
                        if speechService.isRecording { speechService.stopRecording() }
                        Task { await analyzeAndSave() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white.opacity(0.8)) }
                            Text(isSaving ? "Saving…" : "Analyze & Save")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(Color.white.opacity(isSaving ? 0.10 : 0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .disabled(isSaving || textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                    
                    Spacer(minLength: 18)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Capture")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onTapGesture { dismissKeyboard() }
        }
        .onDisappear {
            if speechService.isRecording { speechService.stopRecording() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && speechService.isRecording {
                speechService.stopRecording()
            }
        }
    }
    
    private func analyzeAndSave() async {
        errorMessage = nil
        
        let input = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let result = try await ai.analyze(text: input)
            
            let entry = MindEntry(
                rawTranscript: input,
                title: safe(result.title, max: 56),
                summary: safe(result.summary, max: 260),
                primaryEmotion: safe(result.primaryEmotion.lowercased(), max: 24),
                emotionIntensity: clampInt(result.emotionIntensity, 1, 5),
                growthArea: safe(result.growthArea.lowercased(), max: 24),
                entryType: safe(result.entryType.lowercased(), max: 24),
                topics: [String](result.topics.map { safe($0.lowercased(), max: 18) }.prefix(5)),
                people: [String](result.people.map { safe($0, max: 20) }.prefix(3)),
                loopKey: safe(result.loopKey.lowercased(), max: 48),
                insight: safe(result.insight, max: 240),
                suggestedAction: safe(result.suggestedAction, max: 320)
            )

            await MainActor.run {
                context.insert(entry)
            }
            
            do {
                try context.save()
            } catch {
                await MainActor.run {
                    errorMessage = "DB save failed: \(error.localizedDescription)"
                }
                return
            }
            
            await MainActor.run {
                textInput = ""
                speechService.transcript = ""
                dismissKeyboard()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "AI failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func dismissKeyboard() { isFocused = false }
    
    private func clampInt(_ v: Int, _ minVal: Int, _ maxVal: Int) -> Int {
        max(minVal, min(v, maxVal))
    }
    
    private func safe(_ s: String, max: Int) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        let idx = t.index(t.startIndex, offsetBy: max)
        return String(t[..<idx]) + "…"
    }
}
