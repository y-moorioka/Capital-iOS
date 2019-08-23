/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: GPL-3.0
 */

import Foundation
import RobinHood
import IrohaCommunication

struct WithdrawCheckingState: OptionSet {
    typealias RawValue = UInt8

    static let waiting = WithdrawCheckingState(rawValue: 0)
    static let requestedAmount = WithdrawCheckingState(rawValue: 1)
    static let requestedFee = WithdrawCheckingState(rawValue: 2)
    static let completed = WithdrawCheckingState.requestedAmount.union(.requestedFee)

    var rawValue: WithdrawCheckingState.RawValue

    init(rawValue: WithdrawCheckingState.RawValue) {
        self.rawValue = rawValue
    }
}

final class WithdrawAmountPresenter {

    weak var view: WithdrawAmountViewProtocol?
    var coordinator: WithdrawAmountCoordinatorProtocol
    var logger: WalletLoggerProtocol?

    private var assetSelectionViewModel: AssetSelectionViewModel
    private var amountInputViewModel: AmountInputViewModel
    private var descriptionInputViewModel: DescriptionInputViewModel
    private var feeViewModel: WithdrawFeeViewModel

    private var balances: [BalanceData]?
    private var metadata: WithdrawalData?
    private let dataProviderFactory: DataProviderFactoryProtocol
    private let balanceDataProvider: SingleValueProvider<[BalanceData], CDCWSingleValue>
    private var metaDataProvider: SingleValueProvider<WithdrawalData, CDCWSingleValue>
    private let assetTitleFactory: AssetSelectionFactoryProtocol
    private let withdrawViewModelFactory: WithdrawAmountViewModelFactoryProtocol
    private let assets: [WalletAsset]

    private(set) var selectedAsset: WalletAsset
    private(set) var selectedOption: WalletWithdrawOption

    private(set) var confirmationState: WithdrawCheckingState?

    init(view: WithdrawAmountViewProtocol,
         coordinator: WithdrawAmountCoordinatorProtocol,
         assets: [WalletAsset],
         selectedAsset: WalletAsset,
         selectedOption: WalletWithdrawOption,
         dataProviderFactory: DataProviderFactoryProtocol,
         withdrawViewModelFactory: WithdrawAmountViewModelFactoryProtocol,
         assetTitleFactory: AssetSelectionFactoryProtocol) throws {
        self.view = view
        self.coordinator = coordinator
        self.selectedAsset = selectedAsset
        self.selectedOption = selectedOption
        self.assets = assets
        self.balanceDataProvider = try dataProviderFactory.createBalanceDataProvider()
        self.metaDataProvider = try dataProviderFactory
            .createWithdrawMetadataProvider(for: selectedAsset.identifier, option: selectedOption.identifier)
        self.dataProviderFactory = dataProviderFactory
        self.withdrawViewModelFactory = withdrawViewModelFactory
        self.assetTitleFactory = assetTitleFactory

        let title = assetTitleFactory.createTitle(for: selectedAsset, balanceData: nil)
        assetSelectionViewModel = AssetSelectionViewModel(assetId: selectedAsset.identifier,
                                                          title: title,
                                                          symbol: selectedAsset.symbol)
        assetSelectionViewModel.canSelect = assets.count > 1

        amountInputViewModel = withdrawViewModelFactory.createAmountViewModel()

        let feeTitle = withdrawViewModelFactory.createFeeTitle(for: selectedAsset, amount: nil)
        feeViewModel = WithdrawFeeViewModel(title: feeTitle)
        feeViewModel.isLoading = true

        descriptionInputViewModel = withdrawViewModelFactory.createDescriptionViewModel()
    }

    private func updateFeeViewModel(for asset: WalletAsset) {
        guard
            let amount = amountInputViewModel.decimalAmount,
            let feeRateString = metadata?.feeRate,
            let feeRate = Decimal(string: feeRateString) else {
                feeViewModel.title = withdrawViewModelFactory.createFeeTitle(for: asset, amount: nil)
                feeViewModel.isLoading = true
                return
        }

        let fee = amount * feeRate
        feeViewModel.title = withdrawViewModelFactory.createFeeTitle(for: asset, amount: fee)
        feeViewModel.isLoading = false
    }

    private func updateAccessoryViewModel(for asset: WalletAsset) {
        guard
            let feeRate = metadata?.feeRateDecimal,
            let amount = amountInputViewModel.decimalAmount else {
                let accessoryViewModel = withdrawViewModelFactory.createAccessoryViewModel(for: asset, totalAmount: nil)
                view?.didChange(accessoryViewModel: accessoryViewModel)
                return
        }

        let totalAmount = (1 + feeRate) * amount

        let accessoryViewModel = withdrawViewModelFactory.createAccessoryViewModel(for: asset, totalAmount: totalAmount)
        view?.didChange(accessoryViewModel: accessoryViewModel)
    }

    private func updateSelectedAssetViewModel(for newAsset: WalletAsset) {
        assetSelectionViewModel.isSelecting = false

        assetSelectionViewModel.assetId = newAsset.identifier

        let balanceData = balances?.first { $0.identifier == newAsset.identifier.identifier() }
        let title = assetTitleFactory.createTitle(for: newAsset, balanceData: balanceData)

        assetSelectionViewModel.title = title

        assetSelectionViewModel.symbol = newAsset.symbol
    }

    private func handleBalanceResponse(with optionalBalances: [BalanceData]?) {
        if let balances = optionalBalances {
            self.balances = balances
        }

        guard let balances = self.balances else {
            return
        }

        guard
            let assetId = assetSelectionViewModel.assetId,
            let asset = assets.first(where: { $0.identifier.identifier() == assetId.identifier() }),
            let balanceData = balances.first(where: { $0.identifier == assetId.identifier()}) else {

                if confirmationState != nil {
                   confirmationState = nil

                    let message = "Sorry, we couldn't find asset information you want to send. Please, try again later."
                    view?.showError(message: message)
                }

                return
        }

        assetSelectionViewModel.title = assetTitleFactory.createTitle(for: asset, balanceData: balanceData)

        if let currentState = confirmationState {
            confirmationState = currentState.union(.requestedAmount)
            completeConfirmation()
        }
    }

    private func handleBalanceResponse(with error: Error) {
        if confirmationState != nil {
            confirmationState = nil

            view?.didStopLoading()

            let message = "Sorry, balance checking request failed. Please, try again later."
            view?.showError(message: message)
        }
    }

    private func setupBalanceDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let items), .update(let items):
                    self?.handleBalanceResponse(with: items)
                default:
                    break
                }
            } else {
                self?.handleBalanceResponse(with: nil)
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.handleBalanceResponse(with: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        balanceDataProvider.addCacheObserver(self,
                                             deliverOn: .main,
                                             executing: changesBlock,
                                             failing: failBlock,
                                             options: options)
    }

    private func updateMetadataProvider(for asset: WalletAsset) throws {
        let metaDataProvider = try dataProviderFactory.createWithdrawMetadataProvider(for: asset.identifier,
                                                                                      option: selectedOption.identifier)
        self.metaDataProvider = metaDataProvider

        setupMetadata(provider: metaDataProvider)
    }

    private func handleWithdraw(metadata: WithdrawalData?) {
        if metadata != nil {
            self.metadata = metadata
        }

        updateFeeViewModel(for: selectedAsset)
        updateAccessoryViewModel(for: selectedAsset)

        if let currentState = confirmationState {
            confirmationState = currentState.union(.requestedFee)
            completeConfirmation()
        }
    }

    private func handleWithdrawMetadata(error: Error) {
        if confirmationState != nil {
            view?.didStopLoading()

            let message = "Sorry, we coudn't calculate fee or it might be outdated"
            view?.showError(message: message)
        }
    }

    private func setupMetadata(provider: SingleValueProvider<WithdrawalData, CDCWSingleValue>) {
        let changesBlock = { [weak self] (changes: [DataProviderChange<WithdrawalData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let item), .update(let item):
                    self?.handleWithdraw(metadata: item)
                default:
                    break
                }
            } else {
                self?.handleWithdraw(metadata: nil)
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.handleWithdrawMetadata(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        provider.addCacheObserver(self,
                                  deliverOn: .main,
                                  executing: changesBlock,
                                  failing: failBlock,
                                  options: options)
    }

    private func completeConfirmation() {
        guard confirmationState == .completed else {
            return
        }

        confirmationState = nil

        view?.didStopLoading()

        guard
            let sendingAmount = amountInputViewModel.decimalAmount,
            let metadata = metadata,
            let feeRate = metadata.feeRateDecimal,
            let destinationAccountId = try? IRAccountIdFactory.account(withIdentifier: metadata.accountId) else {
                return
        }

        let totalAmount = (1 + feeRate) * sendingAmount

        guard
            let balanceData = balances?.first(where: { $0.identifier == selectedAsset.identifier.identifier()}),
            let currentAmount =  Decimal(string: balanceData.balance),
            totalAmount <= currentAmount else {
                let message = "Sorry, you don't have enough funds to transfer specified amount."
                view?.showError(message: message)
                return
        }

        guard let irAmount = try? IRAmountFactory.amount(from: (totalAmount as NSNumber).stringValue) else {
            return
        }

        let info = WithdrawInfo(destinationAccountId: destinationAccountId,
                                amount: irAmount,
                                details: descriptionInputViewModel.text,
                                feeAccountId: nil,
                                fee: nil)

        coordinator.confirm(with: info)
    }
}

extension WithdrawAmountPresenter: WithdrawAmountPresenterProtocol {
    func setup() {
        amountInputViewModel.observable.add(observer: self)

        view?.set(title: withdrawViewModelFactory.createWithdrawTitle())
        view?.set(assetViewModel: assetSelectionViewModel)
        view?.set(amountViewModel: amountInputViewModel)
        view?.set(feeViewModel: feeViewModel)
        view?.set(descriptionViewModel: descriptionInputViewModel)

        updateAccessoryViewModel(for: selectedAsset)

        setupBalanceDataProvider()
        setupMetadata(provider: metaDataProvider)
    }

    func confirm() {
        guard confirmationState == nil else {
            return
        }

        view?.didStartLoading()

        confirmationState = .waiting

        balanceDataProvider.refreshCache()
        metaDataProvider.refreshCache()
    }

    func presentAssetSelection() {
        var initialIndex = 0

        if let assetId = assetSelectionViewModel.assetId {
            initialIndex = assets.firstIndex(where: { $0.identifier.identifier() == assetId.identifier() }) ?? 0
        }

        let titles: [String] = assets.map { (asset) in
            let balanceData = balances?.first { $0.identifier == asset.identifier.identifier() }
            return assetTitleFactory.createTitle(for: asset, balanceData: balanceData)
        }

        coordinator.presentPicker(for: titles, initialIndex: initialIndex, delegate: self)

        assetSelectionViewModel.isSelecting = true
    }
}

extension WithdrawAmountPresenter: ModalPickerViewDelegate {
    func modalPickerViewDidCancel(_ view: ModalPickerView) {
        assetSelectionViewModel.isSelecting = false
    }

    func modalPickerView(_ view: ModalPickerView, didSelectRowAt index: Int, in context: AnyObject?) {
        do {
            let newAsset = assets[index]

            if newAsset.identifier.identifier() != selectedAsset.identifier.identifier() {
                self.metadata = nil

                try updateMetadataProvider(for: newAsset)

                self.selectedAsset = newAsset

                updateSelectedAssetViewModel(for: newAsset)
                updateFeeViewModel(for: newAsset)
                updateAccessoryViewModel(for: newAsset)
            }
        } catch {
            logger?.error("Unexpected error when new asset selected \(error)")
        }
    }
}

extension WithdrawAmountPresenter: AmountInputViewModelObserver {
    func amountInputDidChange() {
        updateFeeViewModel(for: selectedAsset)
        updateAccessoryViewModel(for: selectedAsset)
    }
}