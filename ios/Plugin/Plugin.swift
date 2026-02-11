import Foundation
import Capacitor
import Speech

@objc(SpeechRecognition)
public class SpeechRecognition: CAPPlugin, CAPBridgedPlugin {

    public let identifier = "SpeechRecognitionPlugin" 
    public let jsName = "SpeechRecognition" 
    
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getSupportedLanguages", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isListening", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeAllListeners", returnType: CAPPluginReturnPromise)
    ]

    let defaultMatches = 5
    let messageMissingPermission = "Missing permission"
    let messageAccessDeniedMicrophone = "User denied access to microphone"
    let messageOngoing = "Ongoing speech recognition"
    let messageUnknown = "Unknown error occured"

    private var speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    @objc public func available(_ call: CAPPluginCall) {
        let recognizer = SFSpeechRecognizer()
        call.resolve([
            "available": recognizer?.isAvailable ?? false
        ])
    }

    @objc public func start(_ call: CAPPluginCall) {
        // 安全检查：如果引擎已经在运行，直接拒绝
        if let engine = self.audioEngine, engine.isRunning {
            call.reject(self.messageOngoing)
            return
        }

        let status: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
        if status != .authorized {
            call.reject(self.messageMissingPermission)
            return
        }

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] (granted) in
            guard let self = self else { return }
            
            if !granted {
                call.reject(self.messageAccessDeniedMicrophone)
                return
            }

            let language = call.getString("language") ?? "zh-CN"
            let maxResults = call.getInt("maxResults") ?? self.defaultMatches
            let partialResults = call.getBool("partialResults") ?? false

            // 1. 清理旧任务
            self.stopCurrentRecording()

            // 2. 初始化对象
            let engine = AVAudioEngine()
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
            let request = SFSpeechAudioBufferRecognitionRequest()
            
            self.audioEngine = engine
            self.speechRecognizer = recognizer
            self.recognitionRequest = request
            
            request.shouldReportPartialResults = partialResults

            // 3. 配置音频会话
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                call.reject("音频会话配置失败: \(error.localizedDescription)")
                return
            }

            // 4. 启动识别任务
            guard let recognizer = self.speechRecognizer else {
                call.reject("无法创建识别器")
                return
            }

            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (result, error) in
                guard let self = self else { return }
                
                if let result = result {
                    let resultArray = NSMutableArray()
                    for (index, transcription) in result.transcriptions.enumerated() {
                        if maxResults > 0 && index < maxResults {
                            resultArray.add(transcription.formattedString)
                        }
                    }

                    if partialResults {
                        self.notifyListeners("partialResults", data: ["matches": resultArray])
                    } else {
                        if result.isFinal {
                            call.resolve(["matches": resultArray])
                        }
                    }

                    if result.isFinal {
                        self.stopCurrentRecording()
                    }
                }

                if let error = error {
                    self.stopCurrentRecording()
                    // 过滤掉正常的取消错误，避免弹出不必要的报错
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 203 {
                        // 203 是 "No speech detected"，我们可以选择 resolve 空结果或安静地提示
                        self.notifyListeners("partialResults", data: ["matches": []])
                    } else {
                        call.reject(error.localizedDescription)
                    }
                }
            }

            // 5. 配置麦克风输入 Tap
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // 确保先移除旧的 Tap 防止崩溃
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
                request.append(buffer)
            }

            // 6. 启动引擎
            engine.prepare()
            do {
                try engine.start()
                self.notifyListeners("listeningState", data: ["status": "started"])
                if partialResults {
                    call.resolve()
                }
            } catch {
                self.stopCurrentRecording()
                call.reject("引擎启动失败: \(error.localizedDescription)")
            }
        }
    }

    @objc public func stop(_ call: CAPPluginCall) {
        self.stopCurrentRecording()
        call.resolve()
    }

    @objc public func isListening(_ call: CAPPluginCall) {
        call.resolve([
            "listening": self.audioEngine?.isRunning ?? false
        ])
    }

    // --- 内部辅助方法：安全的停止录音 ---
    private func stopCurrentRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
                engine.inputNode.removeTap(onBus: 0)
            }
        }
        
        recognitionRequest?.endAudio()
        
        audioEngine = nil
        speechRecognizer = nil
        recognitionRequest = nil
        
        self.notifyListeners("listeningState", data: ["status": "stopped"])
    }

    @objc public func getSupportedLanguages(_ call: CAPPluginCall) {
        let locales = SFSpeechRecognizer.supportedLocales()
        let languages = locales.map { $0.identifier }
        call.resolve(["languages": languages])
    }

    @objc override public func checkPermissions(_ call: CAPPluginCall) {
        let status = SFSpeechRecognizer.authorizationStatus()
        let permission: String
        switch status {
        case .authorized: permission = "granted"
        case .denied, .restricted: permission = "denied"
        case .notDetermined: permission = "prompt"
        @unknown default: permission = "prompt"
        }
        call.resolve(["speechRecognition": permission])
    }

    @objc override public func requestPermissions(_ call: CAPPluginCall) {
        SFSpeechRecognizer.requestAuthorization { [weak self] (status) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if status == .authorized {
                    AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                        call.resolve(["speechRecognition": granted ? "granted" : "denied"])
                    }
                } else {
                    self.checkPermissions(call)
                }
            }
        }
    }
}