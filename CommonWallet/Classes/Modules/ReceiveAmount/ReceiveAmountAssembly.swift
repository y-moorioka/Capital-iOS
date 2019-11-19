/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation


final class ReceiveAmountAssembly: ReceiveAmountAssemblyProtocol {
    static func assembleView(resolver: ResolverProtocol,
                             selectedAsset: WalletAsset) -> ReceiveAmountViewProtocol? {

        let receiveInfo = ReceiveInfo(accountId: resolver.account.accountId,
                                      assetId: selectedAsset.identifier,
                                      amount: nil,
                                      details: nil)

        let view = ReceiveAmountViewController(nibName: "ReceiveAmountViewController", bundle: Bundle(for: self))
        view.style = resolver.style

        view.title = resolver.receiveConfiguration.title

        let coordinator = ReceiveAmountCoordinator(resolver: resolver)

        let assetSelectionFactory = ReceiveAssetSelectionTitleFactory()

        let qrEncoder = resolver.qrCoderFactory.createEncoder()
        let qrService = WalletQRService(operationFactory: WalletQROperationFactory(),
                                        encoder: qrEncoder)

        let presenter = ReceiveAmountPresenter(view: view,
                                               coordinator: coordinator,
                                               account: resolver.account,
                                               assetSelectionFactory: assetSelectionFactory,
                                               qrService: qrService,
                                               sharingFactory: resolver.receiveConfiguration.accountShareFactory,
                                               receiveInfo: receiveInfo,
                                               amountLimit: resolver.transferAmountLimit)
        view.presenter = presenter

        return view
    }
}
