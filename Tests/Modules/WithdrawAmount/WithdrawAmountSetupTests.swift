/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: GPL-3.0
 */

import XCTest
@testable import CommonWallet
import IrohaCommunication
import Cuckoo

class WithdrawAmountSetupTests: NetworkBaseTests {

    func testSuccessfullSetup() {
        do {
            // given

            let assetId = try IRAssetIdFactory.asset(withIdentifier: Constants.soraAssetId)
            let walletAsset = WalletAsset(identifier: assetId, symbol: "A", details: UUID().uuidString)
            let withdrawOption = createRandomWithdrawOption()

            let accountSettings = try createRandomAccountSettings(for: [walletAsset],
                                                                  withdrawOptions: [withdrawOption])

            let networkResolver = MockWalletNetworkResolverProtocol()

            let cacheFacade = CoreDataTestCacheFacade()

            let networkOperationFactory = WalletServiceOperationFactory(accountSettings: accountSettings)

            let dataProviderFactory = DataProviderFactory(networkResolver: networkResolver,
                                                          accountSettings: accountSettings,
                                                          cacheFacade: cacheFacade,
                                                          networkOperationFactory: networkOperationFactory)

            let amountFormatter = NumberFormatter()
            let viewModelFactory = WithdrawAmountViewModelFactory(amountFormatter: amountFormatter,
                                                                  option: withdrawOption,
                                                                  amountLimit: 100,
                                                                  descriptionMaxLength: 64)

            let view = MockWithdrawAmountViewProtocol()
            let coordinator = MockWithdrawAmountCoordinatorProtocol()

            let assetViewModelObserver = MockAssetSelectionViewModelObserver()
            let feeViewModelObserver = MockWithdrawFeeViewModelObserver()

            // when

            stub(networkResolver) {stub in
                when(stub).urlTemplate(for: any(WalletRequestType.self)).then { type in
                    if type == .balance {
                        return Constants.balanceUrlTemplate
                    } else {
                        return Constants.withdrawalMetadataUrlTemplate
                    }
                }

                when(stub).adapter(for: any(WalletRequestType.self)).thenReturn(nil)
            }

            try FetchBalanceMock.register(mock: .success,
                                          networkResolver: networkResolver,
                                          requestType: .balance,
                                          httpMethod: .post)

            try WithdrawalMetadataMock.register(mock: .success,
                                                networkResolver: networkResolver,
                                                requestType: .withdrawalMetadata,
                                                httpMethod: .get,
                                                urlMockType: .regex)

            let titleExpectation = XCTestExpectation()
            let assetSelectionExpectation = XCTestExpectation()
            let amountExpectation = XCTestExpectation()
            let feeExpectation = XCTestExpectation()
            let descriptionExpectation = XCTestExpectation()
            let accessoryExpectation = XCTestExpectation()
            let balanceLoadedExpectation = XCTestExpectation()
            let feeLoadedExpectation = XCTestExpectation()

            var feeViewModel: WithdrawFeeViewModelProtocol?

            stub(view) { stub in
                when(stub).set(title: any(String.self)).then { _ in
                    titleExpectation.fulfill()
                }

                when(stub).set(assetViewModel: any()).then { viewModel in
                    viewModel.observable.add(observer: assetViewModelObserver)
                    assetSelectionExpectation.fulfill()
                }

                when(stub).set(amountViewModel: any()).then { _ in
                    amountExpectation.fulfill()
                }

                when(stub).set(feeViewModel: any()).then { viewModel in
                    feeViewModel = viewModel
                    viewModel.observable.add(observer: feeViewModelObserver)

                    feeExpectation.fulfill()
                }

                when(stub).set(descriptionViewModel: any()).then { _ in
                    descriptionExpectation.fulfill()
                }

                when(stub).didChange(accessoryViewModel: any()).then { _ in
                    accessoryExpectation.fulfill()
                }
            }

            stub(assetViewModelObserver) { stub in
                when(stub).assetSelectionDidChangeTitle().then {
                    balanceLoadedExpectation.fulfill()
                }
            }

            stub(feeViewModelObserver) { stub in
                when(stub).feeTitleDidChange().thenDoNothing()

                when(stub).feeLoadingStateDidChange().then {
                    if feeViewModel?.isLoading == false {
                        feeLoadedExpectation.fulfill()
                    }
                }
            }

            let presenter = try WithdrawAmountPresenter(view: view,
                                                        coordinator: coordinator,
                                                        assets: accountSettings.assets,
                                                        selectedAsset: walletAsset,
                                                        selectedOption: withdrawOption,
                                                        dataProviderFactory: dataProviderFactory,
                                                        withdrawViewModelFactory: viewModelFactory,
                                                        assetTitleFactory: AssetSelectionFactory(amountFormatter: amountFormatter))

            presenter.setup()

            // then

            wait(for: [titleExpectation,
                       assetSelectionExpectation,
                       amountExpectation,
                       feeExpectation,
                       descriptionExpectation,
                       accessoryExpectation,
                       balanceLoadedExpectation,
                       feeLoadedExpectation], timeout: Constants.networkTimeout)
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }
}