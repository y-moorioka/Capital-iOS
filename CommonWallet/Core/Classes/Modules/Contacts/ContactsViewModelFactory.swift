/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol ContactsFactoryWrapperProtocol {
    func createContactViewModelFromContact(_ contact: SearchData,
                                           accountId: String,
                                           assetId: String,
                                           delegate: ContactViewModelDelegate?) -> ContactViewModelProtocol?
}

final class ContactsFactoryWrapper: ContactsViewModelFactoryProtocol {
    let customFactory: ContactsFactoryWrapperProtocol
    let defaultFactory: ContactsViewModelFactoryProtocol

    init(customFactory: ContactsFactoryWrapperProtocol, defaultFactory: ContactsViewModelFactoryProtocol) {
        self.customFactory = customFactory
        self.defaultFactory = defaultFactory
    }

    func createContactViewModelFromContact(_ contact: SearchData,
                                           accountId: String,
                                           assetId: String,
                                           delegate: ContactViewModelDelegate?) -> ContactViewModelProtocol {
        if let customViewModel = customFactory.createContactViewModelFromContact(contact,
                                                                                 accountId: accountId,
                                                                                 assetId: assetId,
                                                                                 delegate: delegate) {
            return customViewModel
        } else {
            return defaultFactory.createContactViewModelFromContact(contact,
                                                                    accountId: accountId,
                                                                    assetId: assetId,
                                                                    delegate: delegate)
        }
    }
}

protocol ContactsViewModelFactoryProtocol {
    func createContactViewModelFromContact(_ contact: SearchData,
                                           accountId: String,
                                           assetId: String,
                                           delegate: ContactViewModelDelegate?) -> ContactViewModelProtocol
}


final class ContactsViewModelFactory {
    let avatarRadius: CGFloat
    let commandFactory: WalletCommandFactoryProtocol
    let nameIconStyle: WalletNameIconStyleProtocol

    init(commandFactory: WalletCommandFactoryProtocol,
         avatarRadius: CGFloat,
         nameIconStyle: WalletNameIconStyleProtocol) {
        self.commandFactory = commandFactory
        self.avatarRadius = avatarRadius
        self.nameIconStyle = nameIconStyle
    }
}

extension ContactsViewModelFactory: ContactsViewModelFactoryProtocol {
    func createContactViewModelFromContact(_ contact: SearchData,
                                           accountId: String,
                                           assetId: String,
                                           delegate: ContactViewModelDelegate?) -> ContactViewModelProtocol {

        let fullName = L10n.Common.fullName(contact.firstName, contact.lastName)
        let image = UIImage.createAvatar(fullName: fullName,
                                         radius: avatarRadius,
                                         style: nameIconStyle)

        let viewModel = ContactViewModel(cellReuseIdentifier: ContactConstants.contactCellIdentifier,
                                         itemHeight: ContactConstants.contactCellHeight,
                                         contact: contact,
                                         image: image)

        viewModel.delegate = delegate

        return viewModel
    }
}
