/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import AVFoundation
import IrohaCommunication

final class InvoiceScanPresenter {
    enum ScanState {
        case initializing(accessRequested: Bool)
        case inactive
        case active
        case processing(receiverInfo: ReceiveInfo, operation: Operation)
        case failed(code: String)
    }

    weak var view: InvoiceScanViewProtocol?
    var coordinator: InvoiceScanCoordinatorProtocol

    var logger: WalletLoggerProtocol?

    private(set) var networkService: WalletServiceProtocol
    private(set) var currentAccountId: IRAccountId
    private(set) var scanState: ScanState = .initializing(accessRequested: false)

    private let qrScanService: WalletQRCaptureServiceProtocol
    private let qrCoderFactory: WalletQRCoderFactoryProtocol
    private let qrScanMatcher: InvoiceScanMatcher

    var qrExtractionService: WalletQRExtractionServiceProtocol?

    init(view: InvoiceScanViewProtocol,
         coordinator: InvoiceScanCoordinatorProtocol,
         currentAccountId: IRAccountId,
         networkService: WalletServiceProtocol,
         qrScanServiceFactory: WalletQRCaptureServiceFactoryProtocol,
         qrCoderFactory: WalletQRCoderFactoryProtocol) {
        self.view = view
        self.coordinator = coordinator
        self.networkService = networkService
        self.currentAccountId = currentAccountId

        self.qrCoderFactory = qrCoderFactory

        let qrDecoder = qrCoderFactory.createDecoder()
        self.qrScanMatcher = InvoiceScanMatcher(decoder: qrDecoder)

        self.qrScanService = qrScanServiceFactory.createService(with: qrScanMatcher,
                                                                delegate: nil,
                                                                delegateQueue: nil)

        self.qrScanService.delegate = self
    }

    private func handleQRService(error: Error) {
        if let captureError = error as? WalletQRCaptureServiceError {
            handleQRCaptureService(error: captureError)
            return
        }

        if let extractionError = error as? WalletQRExtractionServiceError {
            handleQRExtractionService(error: extractionError)
            return
        }

        if let imageGalleryError = error as? ImageGalleryError {
            handleImageGallery(error: imageGalleryError)
        }

        logger?.error("Unexpected qr service error \(error)")
    }

    private func handleQRCaptureService(error: WalletQRCaptureServiceError) {
        guard case .initializing(let alreadyAskedAccess) = scanState, !alreadyAskedAccess else {
            logger?.warning("Requested to ask access but already done earlier")
            return
        }

        scanState = .initializing(accessRequested: true)

        switch error {
        case .deviceAccessRestricted:
            view?.present(message: "Unfortunatelly, access to the camera is restricted.", animated: true)
        case .deviceAccessDeniedPreviously:
            let message = "Unfortunatelly, you denied access to camera previously. Would you like to allow access now?"
            let title = "Camera Access"
            coordinator.askOpenApplicationSettins(with: message, title: title, from: view)
        default:
            break
        }
    }

    private func handleQRExtractionService(error: WalletQRExtractionServiceError) {
        switch error {
        case .noFeatures:
            view?.present(message: "No valid receiver information found", animated: true)
        case .detectorUnavailable, .invalidImage:
            view?.present(message: "Can't process selected image", animated: true)
        }
    }

    private func handleImageGallery(error: ImageGalleryError) {
        switch error {
        case .accessRestricted:
            view?.present(message: "Unfortunatelly, access to the photos is restricted.", animated: true)
        case .accessDeniedPreviously:
            let message = "Unfortunatelly, you denied access to photos previously. Would you like to allow access now?"
            let title = "Photos Access"
            coordinator.askOpenApplicationSettins(with: message, title: title, from: view)
        default:
            break
        }
    }

    private func handleReceived(captureSession: AVCaptureSession) {
        if case .initializing = scanState {
            scanState = .active

            view?.didReceive(session: captureSession)
        }
    }

    private func handleMatched(receiverInfo: ReceiveInfo) {
        if receiverInfo.accountId.identifier() == currentAccountId.identifier() {
            let message = "Sender and Receiver must be different"
            view?.present(message: message, animated: true)
            return
        }

        switch scanState {
        case .processing(let oldReceiverInfo, let oldOperation) where oldReceiverInfo != receiverInfo:
            if !oldOperation.isFinished {
                oldOperation.cancel()
            }

            performProcessing(of: receiverInfo)
        case .active:
            performProcessing(of: receiverInfo)
        default:
            break
        }
    }

    private func handleFailedMatching(for code: String) {
        let message = "Can't extract receiver's data"
        view?.present(message: message, animated: true)
    }

    private func performProcessing(of receiverInfo: ReceiveInfo) {
        let operation = networkService.search(for: receiverInfo.accountId.identifier(),
                                              runCompletionIn: .main) { [weak self] (optionalResult) in
                                                if let result = optionalResult {
                                                    switch result {
                                                    case .success(let searchResult):
                                                        let loadedResult = searchResult ?? []
                                                        self?.handleProccessing(searchResult: loadedResult)
                                                    case .failure(let error):
                                                        self?.handleProcessing(error: error)
                                                    }
                                                }
        }

        scanState = .processing(receiverInfo: receiverInfo, operation: operation)
    }

    private func handleProccessing(searchResult: [SearchData]) {
        guard case .processing(let receiverInfo, _) = scanState else {
            logger?.warning("Unexpected state \(scanState) after successfull processing")
            return
        }

        scanState = .active

        guard
            let foundAccount = searchResult.first,
            foundAccount.accountId == receiverInfo.accountId.identifier() else {
                let message = "Receiver couldn't be found"
                view?.present(message: message, animated: true)
                return
        }

        let receiverName = "\(foundAccount.firstName) \(foundAccount.lastName)"
        let payload = AmountPayload(receiveInfo: receiverInfo,
                                    receiverName: receiverName)

        coordinator.process(payload: payload)
    }

    private func handleProcessing(error: Error) {
        guard case .processing = scanState else {
            logger?.warning("Unexpected state \(scanState) after failed processing")
            return
        }

        scanState = .active

        let message = "Please, check internet connection"
        view?.present(message: message, animated: true)
    }
}

extension InvoiceScanPresenter: InvoiceScanPresenterProtocol {
    func prepareAppearance() {
        qrScanService.start()
    }

    func handleAppearance() {
        if case .inactive = scanState {
            scanState = .active
        }
    }

    func prepareDismiss() {
        if case .initializing = scanState {
            return
        }

        if case .processing(_, let operation) = scanState, !operation.isFinished {
            operation.cancel()
        }

        scanState = .inactive
    }

    func handleDismiss() {
        qrScanService.stop()
    }

    func activateImport() {
        if qrExtractionService != nil {
            coordinator.presentImageGallery(from: view, delegate: self)
        }
    }
}

extension InvoiceScanPresenter: WalletQRCaptureServiceDelegate {
    func qrCapture(service: WalletQRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.handleReceived(captureSession: captureSession)
        }
    }

    func qrCapture(service: WalletQRCaptureServiceProtocol, didMatch code: String) {
        guard let receiverInfo = qrScanMatcher.receiverInfo else {
            logger?.warning("Can't find receiver's info for matched code")
            return
        }

        DispatchQueue.main.async {
            self.handleMatched(receiverInfo: receiverInfo)
        }
    }

    func qrCapture(service: WalletQRCaptureServiceProtocol, didFailMatching code: String) {
        DispatchQueue.main.async {
            self.handleFailedMatching(for: code)
        }
    }

    func qrCapture(service: WalletQRCaptureServiceProtocol, didReceive error: Error) {
        DispatchQueue.main.async {
            self.handleQRService(error: error)
        }
    }
}

extension InvoiceScanPresenter: ImageGalleryDelegate {
    func didCompleteImageSelection(from gallery: ImageGalleryPresentable,
                                   with selectedImages: [UIImage]) {
        if let image = selectedImages.first {
            let qrDecoder = qrCoderFactory.createDecoder()
            let matcher = InvoiceScanMatcher(decoder: qrDecoder)

            qrExtractionService?.extract(from: image,
                                         using: matcher,
                                         dispatchCompletionIn: .main) { [weak self] result in
                switch result {
                case .success:
                    if let recieverInfo = matcher.receiverInfo {
                        self?.handleMatched(receiverInfo: recieverInfo)
                    }
                case .failure(let error):
                    self?.handleQRService(error: error)
                }
            }
        }
    }

    func didFail(in gallery: ImageGalleryPresentable, with error: Error) {
        handleQRService(error: error)
    }
}
