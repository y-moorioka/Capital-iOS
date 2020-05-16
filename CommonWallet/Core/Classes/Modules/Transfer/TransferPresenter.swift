/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import RobinHood
import SoraFoundation

enum TransferPresenterInitError: Error {
    case missingSelectedAsset
}

enum TransferPresenterValidationError: Error {
    case missingMetadata
    case missingBalances
}

struct TransferCheckingState: OptionSet {
    typealias RawValue = UInt8

    static let waiting: TransferCheckingState = []
    static let requestedAmount = TransferCheckingState(rawValue: 1)
    static let requestedFee = TransferCheckingState(rawValue: 2)
    static let completed = TransferCheckingState.requestedAmount.union(.requestedFee)

    var rawValue: TransferCheckingState.RawValue

    init(rawValue: TransferCheckingState.RawValue) {
        self.rawValue = rawValue
    }
}

final class TransferPresenter {

    weak var view: TransferViewProtocol?
    var coordinator: TransferCoordinatorProtocol
    var logger: WalletLoggerProtocol?
    
    private var amountInputViewModel: AmountInputViewModel
    private var descriptionInputViewModel: DescriptionInputViewModel

    private var feeCalculationFactory: FeeCalculationFactoryProtocol
    private var transferViewModelFactory: TransferViewModelFactoryProtocol
    private var assetSelectionFactory: AssetSelectionFactoryProtocol
    private var accessoryFactory: ContactAccessoryViewModelFactoryProtocol
    private var headerFactory: OperationDefinitionHeaderModelFactoryProtocol
    private var resultValidator: OperationDefinitionValidating

    private let dataProviderFactory: DataProviderFactoryProtocol
    private let balanceDataProvider: SingleValueProvider<[BalanceData]>
    private var metadataProvider: SingleValueProvider<TransferMetaData>

    private var balances: [BalanceData]?
    private var metadata: TransferMetaData?
    private var selectedAsset: WalletAsset
    private let account: WalletAccountSettingsProtocol
    private var payload: AmountPayload
    private let receiverPosition: TransferReceiverPosition

    private(set) var confirmationState: TransferCheckingState?

    init(view: TransferViewProtocol,
         coordinator: TransferCoordinatorProtocol,
         payload: AmountPayload,
         dataProviderFactory: DataProviderFactoryProtocol,
         feeCalculationFactory: FeeCalculationFactoryProtocol,
         account: WalletAccountSettingsProtocol,
         resultValidator: OperationDefinitionValidating,
         transferViewModelFactory: TransferViewModelFactoryProtocol,
         assetSelectionFactory: AssetSelectionFactoryProtocol,
         accessoryFactory: ContactAccessoryViewModelFactoryProtocol,
         headerFactory: OperationDefinitionHeaderModelFactoryProtocol,
         receiverPosition: TransferReceiverPosition,
         localizationManager: LocalizationManagerProtocol?) throws {

        if let assetId = payload.receiveInfo.assetId, let asset = account.asset(for: assetId) {
            selectedAsset = asset
        } else if let asset = account.assets.first {
            selectedAsset = asset
        } else {
            throw TransferPresenterError.missingSelectedAsset
        }

        self.view = view
        self.coordinator = coordinator
        self.account = account
        self.payload = payload
        self.receiverPosition = receiverPosition

        self.dataProviderFactory = dataProviderFactory
        self.balanceDataProvider = try dataProviderFactory.createBalanceDataProvider()
        self.metadataProvider = try dataProviderFactory
            .createTransferMetadataProvider(for: selectedAsset.identifier,
                                            receiver: payload.receiveInfo.accountId)

        self.resultValidator = resultValidator
        self.feeCalculationFactory = feeCalculationFactory
        self.transferViewModelFactory = transferViewModelFactory
        self.assetSelectionFactory = assetSelectionFactory
        self.accessoryFactory = accessoryFactory
        self.headerFactory = headerFactory

        let locale = localizationManager?.selectedLocale ?? Locale.current

        descriptionInputViewModel = try transferViewModelFactory
            .createDescriptionViewModel(for: payload.receiveInfo.details)

        let decimalAmount = payload.receiveInfo.amount?.decimalValue

        amountInputViewModel = transferViewModelFactory.createAmountViewModel(for: selectedAsset,
                                                                              sender: account.accountId,
                                                                              receiver: payload.receiveInfo.accountId,
                                                                              amount: decimalAmount,
                                                                              locale: locale)

        self.localizationManager = localizationManager
    }

    private func setupAmountInputViewModel() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        amountInputViewModel.observable.add(observer: self)

        view?.set(amountViewModel: amountInputViewModel)

        if let amountTitle = headerFactory.createAmountTitle(assetId: selectedAsset.identifier,
                                                             receiverId: payload.receiveInfo.accountId,
                                                             locale: locale) {
            view?.setAmountHeader(amountTitle)
        }
    }

    private func updateAmountInputViewModel() {
        let amount = amountInputViewModel.decimalAmount

        let locale = localizationManager?.selectedLocale ?? Locale.current

        amountInputViewModel.observable.remove(observer: self)

        amountInputViewModel = transferViewModelFactory.createAmountViewModel(for: selectedAsset,
                                                                              sender: account.accountId,
                                                                              receiver: payload.receiveInfo.accountId,
                                                                              amount: amount,
                                                                              locale: locale)

        amountInputViewModel.observable.add(observer: self)

        view?.set(amountViewModel: amountInputViewModel)

        if let amountTitle = headerFactory.createAmountTitle(assetId: selectedAsset.identifier,
                                                             receiverId: payload.receiveInfo.accountId,
                                                             locale: locale) {
            view?.setAmountHeader(amountTitle)
        }
    }

    private func setupFeeViewModel(for asset: WalletAsset) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let amount = amountInputViewModel.decimalAmount ?? 0

        guard let metadata = metadata else {
                return
        }

        do {
            var fee: Decimal?

            // TODO: move to multi fee variant when ui ready

            if let feeDescription = metadata.feeDescriptions.first {
                let feeCalculator = try feeCalculationFactory
                    .createTransferFeeStrategyForDescription(feeDescription,
                                                             assetId: selectedAsset.identifier,
                                                             precision: selectedAsset.precision)
                fee = try feeCalculator.calculate(for: amount).fee
            }

            let viewModel = transferViewModelFactory.createFeeViewModel(for: asset,
                                                                        sender: account.accountId,
                                                                        receiver: payload.receiveInfo.accountId,
                                                                        amount: fee,
                                                                        locale: locale)
            view?.set(feeViewModels: [viewModel])
        } catch {
            let viewModel = transferViewModelFactory.createFeeViewModel(for: asset,
                                                                        sender: account.accountId,
                                                                        receiver: payload.receiveInfo.accountId,
                                                                        amount: nil,
                                                                        locale: locale)
            view?.set(feeViewModels: [viewModel])
        }
    }

    private func setupSelectedAssetViewModel(isSelecting: Bool) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let balanceData = balances?.first { $0.identifier == selectedAsset.identifier }

        let viewModel = assetSelectionFactory.createViewModel(for: selectedAsset,
                                                              balanceData: balanceData,
                                                              locale: locale,
                                                              isSelecting: isSelecting,
                                                              canSelect: account.assets.count > 1)

        view?.set(assetViewModel: viewModel)

        if let assetTitle = headerFactory.createAssetTitle(assetId: selectedAsset.identifier,
                                                           receiverId: payload.receiveInfo.accountId) {
            view?.setAssetHeader(assetTitle)
        }
    }

    private func setupDescriptionViewModel() {
        view?.set(descriptionViewModel: descriptionInputViewModel)

        if let descriptionTitle = headerFactory
            .createDescriptionTitle(assetId: selectedAsset.identifier,
                                    receiverId: payload.receiveInfo.accountId) {
            view?.setDescriptionHeader(descriptionTitle)
        }
    }

    private func updateDescriptionViewModel() {
        do {
            let text = descriptionInputViewModel.text
            descriptionInputViewModel = try transferViewModelFactory.createDescriptionViewModel(for: text)

            view?.set(descriptionViewModel: descriptionInputViewModel)

            if let descriptionTitle = headerFactory
                .createDescriptionTitle(assetId: selectedAsset.identifier,
                                        receiverId: payload.receiveInfo.accountId) {
                view?.setDescriptionHeader(descriptionTitle)
            }
        } catch {
            logger?.error("Can't update description view model")
        }
    }

    private func setupReceiverViewModel() {
        let accessoryViewModel = accessoryFactory.createViewModel(from: payload.receiverName,
                                                                  fullName: payload.receiverName,
                                                                  action: "")

        let viewModel = MultilineTitleIconViewModel(text: accessoryViewModel.title,
                                                    icon: accessoryViewModel.icon)

        view?.set(receiverViewModel: viewModel)

        if let title = headerFactory.createReceiverTitle(assetId: selectedAsset.identifier,
                                                         receiverId: payload.receiveInfo.accountId) {
            view?.setReceiverHeader(title)
        }

    }

    private func setupAccessoryViewModel() {
        let accessoryViewModel: AccessoryViewModelProtocol

        switch receiverPosition {
        case .accessoryBar:
            accessoryViewModel = accessoryFactory.createViewModel(from: payload.receiverName,
                                                                  fullName: payload.receiverName,
                                                                  action: L10n.Common.next)
        default:
            accessoryViewModel = accessoryFactory.createViewModel(from: "",
                                                                  action: L10n.Common.next,
                                                                  icon: nil)
        }

        view?.set(accessoryViewModel: accessoryViewModel)
    }
    
    private func handleResponse(with optionalBalances: [BalanceData]?) {
        if let balances = optionalBalances {
            self.balances = balances
        }

        guard let balances = self.balances else {
            return
        }
        
        guard balances.first(where: { $0.identifier == selectedAsset.identifier}) != nil else {

                if confirmationState != nil {
                    confirmationState = nil

                    let message = L10n.Amount.Error.asset
                    view?.showError(message: message)
                }

            return
        }

        setupSelectedAssetViewModel(isSelecting: false)

        if let currentState = confirmationState {
            confirmationState = currentState.union(.requestedAmount)
            completeConfirmation()
        }
    }

    private func handleResponse(with error: Error) {
        if confirmationState != nil {
            confirmationState = nil

            view?.didStopLoading()

            let message = L10n.Amount.Error.balance
            view?.showError(message: message)
        }
    }
    
    private func setupBalanceDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let items), .update(let items):
                    self?.handleResponse(with: items)
                default:
                    break
                }
            } else {
                self?.handleResponse(with: nil)
            }
        }
        
        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.handleResponse(with: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        balanceDataProvider.addObserver(self,
                                        deliverOn: .main,
                                        executing: changesBlock,
                                        failing: failBlock,
                                        options: options)
    }

    private func handleTransfer(metadata: TransferMetaData?) {
        if metadata != nil {
            self.metadata = metadata
        }

        setupFeeViewModel(for: selectedAsset)

        if let currentState = confirmationState {
            confirmationState = currentState.union(.requestedFee)
            completeConfirmation()
        }
    }

    private func handleTransferMetadata(error: Error) {
        if confirmationState != nil {
            view?.didStopLoading()

            confirmationState = nil
        }

        let message = L10n.Amount.Error.transfer
        view?.showError(message: message)
    }

    private func updateMetadataProvider(for asset: WalletAsset) throws {
        let metaDataProvider = try dataProviderFactory
            .createTransferMetadataProvider(for: asset.identifier,
                                            receiver: payload.receiveInfo.accountId)
        self.metadataProvider = metaDataProvider

        setupMetadata(provider: metaDataProvider)
    }

    private func setupMetadata(provider: SingleValueProvider<TransferMetaData>) {
        let changesBlock = { [weak self] (changes: [DataProviderChange<TransferMetaData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let item), .update(let item):
                    self?.handleTransfer(metadata: item)
                default:
                    break
                }
            } else {
                self?.handleTransfer(metadata: nil)
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.handleTransferMetadata(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        provider.addObserver(self,
                             deliverOn: .main,
                             executing: changesBlock,
                             failing: failBlock,
                             options: options)
    }

    private func prepareTransferInfo() throws -> TransferInfo {
        let inputAmount = amountInputViewModel.decimalAmount ?? 0

        guard let metadata = metadata else {
            logger?.error("Metadata missing to complete transfer")
            throw TransferPresenterValidationError.missingMetadata
        }

        guard let balances = balances else {
            logger?.error("Balances missing to complete transfer")
            throw TransferPresenterValidationError.missingBalances
        }

        let calculator = try feeCalculationFactory
            .createTransferFeeStrategyForDescriptions(metadata.feeDescriptions,
                                                      assetId: selectedAsset.identifier,
                                                      precision: selectedAsset.precision)

        let result = try calculator.calculate(for: inputAmount)

        let info = TransferInfo(source: account.accountId,
                                destination: payload.receiveInfo.accountId,
                                amount: AmountDecimal(value: result.sending),
                                asset: selectedAsset.identifier,
                                details: descriptionInputViewModel.text,
                                fees: result.fees)

        try resultValidator.validate(info: info, balances: balances)
    }

    private func validateAndReportLimitConstraints(for amount: Decimal) -> Bool {
        guard amount >= transferViewModelFactory.minimumLimit(for: selectedAsset,
                                                              sender: account.accountId,
                                                              receiver: payload.receiveInfo.accountId) else {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let receiverId = payload.receiveInfo.accountId
            let message = transferViewModelFactory.createMinimumLimitErrorDetails(for: selectedAsset,
                                                                                  sender: account.accountId,
                                                                                  receiver: receiverId,
                                                                                  locale: locale)
            view?.showError(message: message)
            return false
        }

        return true
    }

    private func validateAndReportBalanceConstraints(for amount: Decimal) -> Bool {
        guard
            let balanceData = balances?
                .first(where: { $0.identifier == selectedAsset.identifier}),
            amount <= balanceData.balance.decimalValue else {
                let message = L10n.Amount.Error.noFunds
                view?.showError(message: message)
                return false
        }

        return true
    }

    private func completeConfirmation() {
        guard confirmationState == .completed else {
            return
        }

        confirmationState = nil

        view?.didStopLoading()

        if let transferInfo = prepareTransferInfo() {
            let composedPayload = TransferPayload(transferInfo: transferInfo,
                                                  receiverName: payload.receiverName,
                                                  assetSymbol: selectedAsset.symbol)

            coordinator.confirm(with: composedPayload)
        }
    }
}


extension TransferPresenter: OperationDefinitionPresenterProtocol {

    func setup() {
        setupSelectedAssetViewModel(isSelecting: false)
        setupAmountInputViewModel()
        setupFeeViewModel(for: selectedAsset)
        setupDescriptionViewModel()

        if receiverPosition == .form {
            setupReceiverViewModel()
        }

        setupAccessoryViewModel()

        setupBalanceDataProvider()
        setupMetadata(provider: metadataProvider)
    }
    
    func proceed() {
        guard confirmationState == nil else {
            return
        }

        view?.didStartLoading()

        confirmationState = .waiting

        balanceDataProvider.refresh()
        metadataProvider.refresh()
    }
    
    func presentAssetSelection() {
        let initialIndex = account.assets.firstIndex(where: { $0.identifier == selectedAsset.identifier }) ?? 0

        let titles: [String] = account.assets.map { (asset) in
            let balanceData = balances?.first { $0.identifier == asset.identifier }

            let locale = localizationManager?.selectedLocale ?? Locale.current
            return assetSelectionFactory.createTitle(for: asset, balanceData: balanceData, locale: locale)
        }

        coordinator.presentPicker(for: titles, initialIndex: initialIndex, delegate: self)

        setupSelectedAssetViewModel(isSelecting: true)
    }

    func presentFeeEditing(at index: Int) {
        
    }
}

extension TransferPresenter: ModalPickerViewDelegate {
    func modalPickerViewDidCancel(_ view: ModalPickerView) {
        setupSelectedAssetViewModel(isSelecting: false)
    }

    func modalPickerView(_ view: ModalPickerView, didSelectRowAt index: Int, in context: AnyObject?) {
        do {
            let newAsset = account.assets[index]

            if newAsset.identifier != selectedAsset.identifier {
                self.metadata = nil

                try updateMetadataProvider(for: newAsset)

                self.selectedAsset = newAsset

                setupSelectedAssetViewModel(isSelecting: false)

                setupFeeViewModel(for: newAsset)
                updateAmountInputViewModel()
            }
        } catch {
            logger?.error("Unexpected error when new asset selected \(error)")
        }
    }
}

extension TransferPresenter: AmountInputViewModelObserver {
    func amountInputDidChange() {
        setupFeeViewModel(for: selectedAsset)
    }
}

extension TransferPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateAmountInputViewModel()
            setupSelectedAssetViewModel(isSelecting: false)
            setupFeeViewModel(for: selectedAsset)
            updateDescriptionViewModel()
            setupAccessoryViewModel()

            if receiverPosition == .form {
                setupReceiverViewModel()
            }
        }
    }
}
