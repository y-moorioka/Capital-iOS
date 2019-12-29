/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import RobinHood
import IrohaCommunication
import SoraFoundation


final class ReceiveAmountPresenter {
    weak var view: ReceiveAmountViewProtocol?
    var coordinator: ReceiveAmountCoordinatorProtocol

    private(set) var qrService: WalletQRServiceProtocol
    private(set) var sharingFactory: AccountShareFactoryProtocol
    private(set) var account: WalletAccountSettingsProtocol
    private(set) var assetSelectionFactory: AssetSelectionFactoryProtocol
    private(set) var assetSelectionViewModel: AssetSelectionViewModel
    private(set) var amountInputViewModel: AmountInputViewModel
    private(set) var preferredQRSize: CGSize?
    private(set) var selectedAsset: WalletAsset?

    private var currentImage: UIImage?

    var logger: WalletLoggerProtocol?

    private var qrOperation: Operation?

    deinit {
        cancelQRGeneration()
    }

    init(view: ReceiveAmountViewProtocol,
         coordinator: ReceiveAmountCoordinatorProtocol,
         account: WalletAccountSettingsProtocol,
         assetSelectionFactory: AssetSelectionFactoryProtocol,
         qrService: WalletQRServiceProtocol,
         sharingFactory: AccountShareFactoryProtocol,
         receiveInfo: ReceiveInfo,
         amountLimit: Decimal,
         localizationManager: LocalizationManagerProtocol?) {
        self.view = view
        self.coordinator = coordinator
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.account = account
        self.assetSelectionFactory = assetSelectionFactory

        var currentAmount: Decimal?

        if let assetId = receiveInfo.assetId, let asset = account.asset(for: assetId.identifier()) {
            selectedAsset = asset

            if let amount = receiveInfo.amount {
                currentAmount = Decimal(string: amount.value) ?? 0
            }
        } else {
            selectedAsset = account.assets.first
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let title = assetSelectionFactory.createTitle(for: selectedAsset, balanceData: nil, locale: locale)
        assetSelectionViewModel = AssetSelectionViewModel(assetId: selectedAsset?.identifier,
                                                          title: title,
                                                          symbol: selectedAsset?.symbol ?? "")
        assetSelectionViewModel.canSelect = account.assets.count > 1

        amountInputViewModel = AmountInputViewModel(amount: currentAmount, limit: amountLimit)

        self.localizationManager = localizationManager
    }

    // MARK: QR generation

    private func generateQR(with size: CGSize) {
        cancelQRGeneration()

        currentImage = nil

        do {
            guard let receiveInfo = createReceiveInfo() else {
                return
            }

            qrOperation = try qrService.generate(from: receiveInfo, qrSize: size,
                                                 runIn: .main) { [weak self] (operationResult) in
                                                    if let result = operationResult {
                                                        self?.qrOperation = nil
                                                        self?.processOperation(result: result)
                                                    }
            }
        } catch {
            processOperation(result: .failure(error))
        }
    }

    private func createReceiveInfo() -> ReceiveInfo? {

        guard let assetId = assetSelectionViewModel.assetId else {
            return nil
        }

        var amount: IRAmount?

        if let decimalAmount = amountInputViewModel.decimalAmount, decimalAmount > 0 {
            amount = try? IRAmountFactory.amount(from: (decimalAmount as NSNumber).stringValue)
        }

        return ReceiveInfo(accountId: account.accountId,
                           assetId: assetId,
                           amount: amount,
                           details: nil)
    }

    private func cancelQRGeneration() {
        qrOperation?.cancel()
        qrOperation = nil
    }

    private func processOperation(result: Result<UIImage, Error>) {
        switch result {
        case .success(let image):
            currentImage = image
            view?.didReceive(image: image)
        case .failure:
            view?.showError(message: L10n.Receive.errorQrGeneration)
        }
    }
}


extension ReceiveAmountPresenter: ReceiveAmountPresenterProtocol {
    func setup(qrSize: CGSize) {
        assetSelectionViewModel.observable.remove(observer: self)
        assetSelectionViewModel.observable.add(observer: self)

        amountInputViewModel.observable.remove(observer: self)
        amountInputViewModel.observable.add(observer: self)

        view?.didReceive(assetSelectionViewModel: assetSelectionViewModel)
        view?.didReceive(amountInputViewModel: amountInputViewModel)

        self.preferredQRSize = qrSize

        generateQR(with: qrSize)
    }

    func presentAssetSelection() {
        var initialIndex = 0

        if let assetId = assetSelectionViewModel.assetId {
            initialIndex = account.assets.firstIndex(where: { $0.identifier.identifier() == assetId.identifier() }) ?? 0
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let titles: [String] = account.assets.map { (asset) in
            return assetSelectionFactory.createTitle(for: asset, balanceData: nil, locale: locale)
        }

        coordinator.presentPicker(for: titles, initialIndex: initialIndex, delegate: self)

        assetSelectionViewModel.isSelecting = true
    }

    func share() {
        if let qrImage = currentImage, let receiveInfo = createReceiveInfo() {
            let sources = sharingFactory.createSources(for: receiveInfo,
                                                       qrImage: qrImage)

            coordinator.share(sources: sources,
                              from: view,
                              with: nil)
        }
    }
}

extension ReceiveAmountPresenter: AssetSelectionViewModelObserver {
    func assetSelectionDidChangeTitle() {}

    func assetSelectionDidChangeSymbol() {
        if let qrSize = preferredQRSize {
            generateQR(with: qrSize)
        }
    }

    func assetSelectionDidChangeState() {}
}

extension ReceiveAmountPresenter: AmountInputViewModelObserver {
    func amountInputDidChange() {
        if let qrSize = preferredQRSize {
            generateQR(with: qrSize)
        }
    }
}

extension ReceiveAmountPresenter: ModalPickerViewDelegate {
    func modalPickerViewDidCancel(_ view: ModalPickerView) {
        assetSelectionViewModel.isSelecting = false
    }

    func modalPickerView(_ view: ModalPickerView, didSelectRowAt index: Int, in context: AnyObject?) {
        assetSelectionViewModel.isSelecting = false

        let newAsset = account.assets[index]

        selectedAsset = newAsset

        assetSelectionViewModel.assetId = newAsset.identifier

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let title = assetSelectionFactory.createTitle(for: newAsset, balanceData: nil, locale: locale)

        assetSelectionViewModel.title = title

        assetSelectionViewModel.symbol = newAsset.symbol
    }

    func close() {
        coordinator.close()
    }
}

extension ReceiveAmountPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            assetSelectionViewModel.title = assetSelectionFactory.createTitle(for: selectedAsset,
                                                                              balanceData: nil,
                                                                              locale: locale)
        }
    }
}
