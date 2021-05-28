/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol TransactionCellStyleProtocol {
    var backgroundColor: UIColor { get }
    var title: WalletTextStyleProtocol { get }
    var amount: WalletTextStyleProtocol { get }
    var statusStyleContainer: WalletTransactionStatusStyleContainerProtocol { get }
    var increaseAmountIcon: UIImage? { get }
    var decreaseAmountIcon: UIImage? { get }
    var separatorColor: UIColor { get }
    var timestamp: WalletTextStyleProtocol { get }
}

public struct TransactionCellStyle: TransactionCellStyleProtocol {
    public var backgroundColor: UIColor
    public var title: WalletTextStyleProtocol
    public var amount: WalletTextStyleProtocol
    public var statusStyleContainer: WalletTransactionStatusStyleContainerProtocol
    public var increaseAmountIcon: UIImage?
    public var decreaseAmountIcon: UIImage?
    public var separatorColor: UIColor
    public var timestamp: WalletTextStyleProtocol

    public init(backgroundColor: UIColor,
                title: WalletTextStyleProtocol,
                amount: WalletTextStyleProtocol,
                statusStyleContainer: WalletTransactionStatusStyleContainerProtocol,
                increaseAmountIcon: UIImage?,
                decreaseAmountIcon: UIImage?,
                separatorColor: UIColor,
                timestamp: WalletTextStyleProtocol) {
        self.backgroundColor = backgroundColor
        self.title = title
        self.amount = amount
        self.statusStyleContainer = statusStyleContainer
        self.increaseAmountIcon = increaseAmountIcon
        self.decreaseAmountIcon = decreaseAmountIcon
        self.separatorColor = separatorColor
        self.timestamp = timestamp
    }
}

extension TransactionCellStyle {
    static func createDefaultStyle(with style: WalletStyleProtocol) -> TransactionCellStyle {
        let color = UserDefaults.standard.string(forKey: TransferLabel.role)?.backgroundColor
        return TransactionCellStyle(backgroundColor: color!,
                                    title: WalletTextStyle(font: style.bodyRegularFont, color: style.bodyTextColor),
                                    amount: WalletTextStyle(font: style.bodyRegularFont, color: style.bodyTextColor),
                                    statusStyleContainer: style.statusStyleContainer,
                                    increaseAmountIcon: style.amountChangeStyle.increase,
                                    decreaseAmountIcon: style.amountChangeStyle.decrease,
                                    separatorColor: style.thinBorderColor,
                                    timestamp: WalletTextStyle(font: style.smallFont, color: style.captionTextColor))
    }
}
