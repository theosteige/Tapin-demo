/**
 * An observable object class responsible for handling Near Field Communication (NFC)
 * interactions using CoreNFC.
 *
 * This class encapsulates the logic for:
 * - Starting and managing NFC reader sessions for both reading and writing NDEF data.
 * - Conforming to `NFCNDEFReaderSessionDelegate` to receive callbacks during the session.
 * - Reading NDEF messages from compatible NFC tags, extracting text or URI payloads.
 * - Writing NDEF text messages to writable NFC tags.
 * - Providing completion handlers (`onScanComplete`, `onWriteComplete`) to return results
 *   asynchronously.
 * - Handling session errors and invalidation.
 * - Includes basic simulator support for the `scan` function.
 */

//
//  NfcReader.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//

import CoreNFC

class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var message = "Waiting for NFC tag..."
    var session: NFCNDEFReaderSession?
    var onScanComplete: ((String) -> Void)?
    var onWriteComplete: ((Bool) -> Void)?
    var isWriting = false
    var textToWrite: String?
    
//    func scan(completion: @escaping (String) -> Void) {
//        self.onScanComplete = completion
//        self.isWriting = false
//        startSession()
//    }
    
    func scan(completion: @escaping (String) -> Void) {
        #if targetEnvironment(simulator)
        // Simulate a valid NFC scan by returning a unique space tag ID after a short delay
        // In a real test setup, you might want to cycle through a few known test tag IDs
        // or have a way to input which tag ID the simulator should mock.
        let simulatedSpaceTagID = "BROKE-SPACE-\(UUID().uuidString)" // Example of a unique ID
        NSLog("NFCReader: Simulating scan of '\\(simulatedSpaceTagID)' on Simulator")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(simulatedSpaceTagID)
        }
        #else
        self.onScanComplete = completion
        self.isWriting = false
        startSession()
        #endif
    }

    
    func write(_ text: String, completion: @escaping (Bool) -> Void) {
        #if targetEnvironment(simulator)
        NSLog("NFCReader: Simulating successful write of '\(text)' on Simulator")
        // Simulate a small delay and success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(true)
        }
        #else
        self.onWriteComplete = completion
        self.textToWrite = text
        self.isWriting = true
        startSession()
        #endif
    }
    
    private func startSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            NSLog("NFC is not available on this device")
            return
        }
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = isWriting ? "Hold your iPhone near an NFC tag to write." : "Hold your iPhone near an NFC tag to read."
        session?.begin()
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard !isWriting else { return }
        
        for message in messages {
            for record in message.records {
                if record.typeNameFormat == .nfcWellKnown {
                    if let text = record.wellKnownTypeTextPayload().0 {
                        DispatchQueue.main.async {
                            self.message = text
                            self.onScanComplete?(text)
                        }
                    }
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if isWriting {
            handleWriting(session: session, tags: tags)
        } else {
            handleReading(session: session, tags: tags)
        }
    }
    
    private func handleReading(session: NFCNDEFReaderSession, tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "More than 1 tag detected. Please try again with only one tag."
            session.invalidate()
            return
        }
        
        let tag = tags.first!
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, _, error in
                if let error = error {
                    session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
                    return
                }
                
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
                case .readOnly, .readWrite:
                    tag.readNDEF { message, error in
                        if let error = error {
                            session.invalidate(errorMessage: "Read error: \(error.localizedDescription)")
                        } else if let message = message {
                            self.processMessage(message)
                            session.alertMessage = "Tag read successfully!"
                            session.invalidate()
                        } else {
                            session.invalidate(errorMessage: "No NDEF message found on tag")
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }
    
    private func processMessage(_ message: NFCNDEFMessage) {
        for record in message.records {
            switch record.typeNameFormat {
            case .nfcWellKnown:
                if let text = record.wellKnownTypeTextPayload().0 {
                    DispatchQueue.main.async {
                        self.message = text
                        self.onScanComplete?(text)
                    }
                } else if let url = record.wellKnownTypeURIPayload() {
                    DispatchQueue.main.async {
                        self.message = url.absoluteString
                        self.onScanComplete?(url.absoluteString)
                    }
                }
            case .absoluteURI:
                if let text = String(data: record.payload, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.message = text
                        self.onScanComplete?(text)
                    }
                }
            default:
                break
            }
        }
    }
    
    private func handleWriting(session: NFCNDEFReaderSession, tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag detected")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Failed to query tag")
                    return
                }
                
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only")
                case .readWrite:
                    guard let textToWrite = self.textToWrite else {
                        session.invalidate(errorMessage: "No text to write")
                        return
                    }
                    
                    let payload = NFCNDEFPayload.wellKnownTypeTextPayload(string: textToWrite, locale: Locale(identifier: "en"))!
                    let message = NFCNDEFMessage(records: [payload])
                    
                    tag.writeNDEF(message) { error in
                        if let error = error {
                            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                        } else {
                            session.alertMessage = "Write successful!"
                            session.invalidate()
                        }
                        
                        DispatchQueue.main.async {
                            self.onWriteComplete?(error == nil)
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                NSLog("Session invalidated with error: \(error.localizedDescription)")
            }
        }
        self.session = nil
    }
}
