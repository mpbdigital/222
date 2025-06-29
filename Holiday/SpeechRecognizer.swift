import Foundation
import Speech
import AVFoundation
import CoreGraphics

class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var amplitude: CGFloat = 0

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var completionHandler: ((String) -> Void)?

    func startRecording() {
        transcript = ""
        completionHandler = nil
        amplitude = 0
        stopCurrentTask()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)

            let frameLength = Int(buffer.frameLength)
            if let channelData = buffer.floatChannelData?[0] {
                let bufferPointer = UnsafeBufferPointer(start: channelData, count: frameLength)
                let rms = sqrt(bufferPointer.reduce(0) { $0 + $1 * $1 } / Float(frameLength))
                DispatchQueue.main.async {
                    // Применяем масштабирование, чтобы амплитуда была в диапазоне 0...1
                    let normalized = min(1, CGFloat(rms) * 10) // коэффициент 10 подобран экспериментально
                    self.amplitude = normalized
                }
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self.completionHandler?(self.transcript)
                    self.completionHandler = nil
                }
                self.finishRecognition()
            }
        }
    }

    func stopRecording(completion: ((String) -> Void)? = nil) {
        completionHandler = completion
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        amplitude = 0
    }

    private func finishRecognition() {
        stopCurrentTask()
    }

    private func stopCurrentTask() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        amplitude = 0
    }
}
