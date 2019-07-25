/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import CommonWallet
import Cuckoo
import RobinHood

class HistoryTests: NetworkBaseTests {

    func testSetup() {
        [1, 2, 4].forEach { performTestSetup(assetsCount: $0) }
    }

    func testFilterAndThenReset() {
        [1, 2, 4].forEach { performTestFilterAndThenReset(assetsCount: $0) }
    }

    // MARK: Private

    private func performTestFilterAndThenReset(assetsCount: Int) {
        do {
            let accountSettings = try createRandomAccountSettings(for: assetsCount)
            let networkResolver = MockWalletNetworkResolverProtocol()
            let view = MockHistoryViewProtocol()
            let coordinator = MockHistoryCoordinatorProtocol()

            let presenter = try performSetup(view: view,
                                             coordinator: coordinator,
                                             networkResolver: networkResolver,
                                             accountSettings: accountSettings)

            // filter

            var historyRequest = WalletHistoryRequest()
            historyRequest.type = UUID().uuidString

            performFilter(for: presenter,
                          view: view,
                          coordinator: coordinator,
                          resultFilterRequest: historyRequest)

            // reset filter

            performFilter(for: presenter,
                          view: view,
                          coordinator: coordinator,
                          resultFilterRequest: WalletHistoryRequest())

        } catch {
            XCTFail("\(error)")
        }
    }

    private func performTestSetup(assetsCount: Int) {
        do {
            let accountSettings = try createRandomAccountSettings(for: assetsCount)
            let networkResolver = MockWalletNetworkResolverProtocol()
            let view = MockHistoryViewProtocol()
            let coordinator = MockHistoryCoordinatorProtocol()

            _ = try performSetup(view: view,
                                 coordinator: coordinator,
                                 networkResolver: networkResolver,
                                 accountSettings: accountSettings)

        } catch {
            XCTFail("\(error)")
        }
    }

    private func performFilter(for presenter: HistoryPresenter,
                               view: MockHistoryViewProtocol,
                               coordinator: MockHistoryCoordinatorProtocol,
                               resultFilterRequest: WalletHistoryRequest) {
        stub(coordinator) { stub in
            when(stub).presentFilter(filter: any(WalletHistoryRequest.self), assets: any([WalletAsset].self)).then { (filter, assets) in
                presenter.coordinator(coordinator, didReceive: resultFilterRequest)
            }
        }

        let filterCompletionExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).handle(changes: any()).then { _ in
                filterCompletionExpectation.fulfill()
            }
        }

        presenter.showFilter()

        wait(for: [filterCompletionExpectation], timeout: Constants.networkTimeout)
    }

    private func performSetup(view: MockHistoryViewProtocol,
                              coordinator: MockHistoryCoordinatorProtocol,
                              networkResolver: MockWalletNetworkResolverProtocol,
                              accountSettings: WalletAccountSettings) throws -> HistoryPresenter {
        // given

        let cacheFacade = CoreDataTestCacheFacade()

        let networkOperationFactory = WalletServiceOperationFactory(accountSettings: accountSettings)

        let dataProviderFactory = DataProviderFactory(networkResolver: networkResolver,
                                                      accountSettings: accountSettings,
                                                      cacheFacade: cacheFacade,
                                                      networkOperationFactory: networkOperationFactory)

        let dataProvider = try dataProviderFactory.createHistoryDataProvider(for: accountSettings.assets.map( { $0.identifier }))

        let walletService = WalletService(networkResolver: networkResolver,
                                          operationFactory: networkOperationFactory)

        let viewModelFactory = HistoryViewModelFactory(dateFormatter: DateFormatter.historyDateFormatter,
                                                       amountFormatter: NumberFormatter(),
                                                       assets: accountSettings.assets)

        // when

        stub(networkResolver) { stub in
            when(stub).urlTemplate(for: any(WalletRequestType.self)).then { _ in
                return Constants.historyUrlTemplate
            }

            when(stub).adapter(for: any(WalletRequestType.self)).then { _ in
                return nil
            }
        }

        try FetchHistoryMock.register(mock: .success,
                                      networkResolver: networkResolver,
                                      requestType: .history,
                                      httpMethod: .post,
                                      urlMockType: .regex)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        stub(view) { stub in
            when(stub).reloadContent().then {
                expectation.fulfill()
            }
        }

        let presenter = HistoryPresenter(view: view,
                                         coordinator: coordinator,
                                         dataProvider: dataProvider,
                                         walletService: walletService,
                                         viewModelFactory: viewModelFactory,
                                         assets: accountSettings.assets,
                                         transactionsPerPage: 100)

        presenter.setup()

        // then

        wait(for: [expectation], timeout: Constants.networkTimeout)

        guard presenter.viewModels.count > 0 else {
            XCTFail("Must be single page")
            return presenter
        }

        guard presenter.viewModels[0].items.count > 0 else {
            XCTFail("Section must not be empty")
            return presenter
        }

        return presenter
    }
}
