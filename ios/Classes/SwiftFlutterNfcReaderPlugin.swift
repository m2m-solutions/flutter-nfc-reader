import Flutter
import Foundation
import CoreNFC
import VYNFCKit

@available(iOS 11.0, *)
public class SwiftFlutterNfcReaderPlugin: NSObject, FlutterPlugin {
    fileprivate var nfcSession: NFCTagReaderSession? = nil
    fileprivate var instruction: String? = nil
    fileprivate var resulter: FlutterResult? = nil
    fileprivate var readResult: FlutterResult? = nil
    
    private var eventSink: FlutterEventSink?
    
    fileprivate let kId = "nfcId"
    fileprivate let kContent = "nfcContent"
    fileprivate let kStatus = "nfcStatus"
    fileprivate let kError = "nfcError"
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_nfc_reader", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "it.matteocrippa.flutternfcreader.flutter_nfc_reader", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterNfcReaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case "NfcRead":
            let map = call.arguments as? Dictionary<String, String>
            instruction = map?["instruction"] ?? ""
            readResult = result
            print("read")
            activateNFC(instruction)
        case "NfcStop":
            resulter = result
            disableNFC()
        case "NfcWrite":
            let alertController = UIAlertController(title: nil, message: "IOS does not support NFC tag writing", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true)
        case "NfcAvailable":
        let nfcAvailable = NFCNDEFReaderSession.readingAvailable
            result(nfcAvailable ? "available" : "not_supported")
        default:
            result("iOS " + UIDevice.current.systemVersion)
        }
    }
}

// MARK: - NFC Actions
@available(iOS 11.0, *)
extension SwiftFlutterNfcReaderPlugin {
    func activateNFC(_ instruction: String?) {
        print("activate")
        
        nfcSession = NFCTagReaderSession(
            pollingOption: [.iso14443],
            delegate: self, 
            queue: DispatchQueue(label: "queueName", attributes: .concurrent)
        )
        
        // then setup a new session
        if let instruction = instruction {
            nfcSession?.alertMessage = instruction
        }
        
        // start
        if let nfcSession = nfcSession {
            nfcSession.begin()
        }
    }
    
    func disableNFC() {
        let data = [kId: "", kContent: "", kError: "", kStatus: "stopped"]
        
        resulter?(data)
        resulter = nil
    }
    
    func sendNfcEvent(data: [String: String]){
        guard let eventSink = eventSink else {
            return
        }
        eventSink(data)
    }
}

// MARK: - NFCDelegate
@available(iOS 11.0, *)
extension SwiftFlutterNfcReaderPlugin : NFCTagReaderSessionDelegate {
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {

    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        let tag = tags.first!
        guard case .miFare(let mifareTag) = tag else {return}

        let id = "0x" + mifareTag.identifier
            .reversed()
            .map { (data) -> String in
                return String(format: "%02x", data)
            }
            .joined()
        
        let data = [kId: id, kContent: "notimplemented", kError: "", kStatus: "reading"]
        sendNfcEvent(data: data);
        readResult?(data)
        readResult=nil
        session.invalidate()
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print(error.localizedDescription)
        let data = [kId: "", kContent: "", kError: error.localizedDescription, kStatus: "error"]
        resulter?(data)
        disableNFC()
    }
}

@available(iOS 11.0, *)
extension SwiftFlutterNfcReaderPlugin: FlutterStreamHandler {
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
}