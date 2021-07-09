/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import SoraUI

final class ActionsCollectionViewCell: UICollectionViewCell {
    @IBOutlet private var sendButton: RoundedButton!
    @IBOutlet private var receiveButton: RoundedButton!
    @IBOutlet private var separatorView: UIView!

    private(set) var actionsViewModel: ActionsViewModelProtocol?
    
    weak var delegate: AlertPresentable?

    override func prepareForReuse() {
        super.prepareForReuse()

        actionsViewModel = nil
    }

    @IBAction private func actionSend() {
        if let actionsViewModel = actionsViewModel {
            self.delegate?.showAlert(title: L10n.Notify.confirmTitle, message: L10n.Notify.confirmDescription, actions: [(L10n.Notify.confirmNo, .cancel), (L10n.Notify.confirmYes, .default)], completion: { Int in
                if Int == 0 {
                    try? actionsViewModel.send.command.execute()
                } else {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    }
                }
            })
        }
    }

    @IBAction private func actionReceive() {
        if let actionsViewModel = actionsViewModel {
            try? actionsViewModel.receive.command.execute()
        }
    }
}

extension ActionsCollectionViewCell: WalletViewProtocol {
    var viewModel: WalletViewModelProtocol? {
        return actionsViewModel
    }

    func bind(viewModel: WalletViewModelProtocol) {
        if let actionsViewModel = viewModel as? ActionsViewModelProtocol {
            self.actionsViewModel = actionsViewModel

            sendButton.imageWithTitleView?.title = actionsViewModel.send.title
            receiveButton.imageWithTitleView?.title = actionsViewModel.receive.title
            sendButton.imageWithTitleView?.titleColor = actionsViewModel.send.style.color
            sendButton.imageWithTitleView?.titleFont = actionsViewModel.send.style.font
            receiveButton.imageWithTitleView?.titleColor = actionsViewModel.receive.style.color
            receiveButton.imageWithTitleView?.titleFont = actionsViewModel.receive.style.font

            sendButton.invalidateLayout()
            receiveButton.invalidateLayout()
        }
    }
}
