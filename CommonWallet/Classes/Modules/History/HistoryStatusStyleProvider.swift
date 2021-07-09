/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

final class HistoryStatusStyleProvider: TransactionStatusDesignable {
    func fetchColor(for status: AssetTransactionStatus,
                    incoming: Bool,
                    style: TransactionCellStyleProtocol) -> UIColor {
        switch status {
        case .commited:
            return incoming ? style.statusStyleContainer.approved.color : style.amount.color
        case .pending, .rejected:
            return style.amount.color
        }
    }

    func fetchIcon(for status: AssetTransactionStatus,
                   incoming: Bool,
                   style: TransactionCellStyleProtocol) -> UIImage? {
        switch status {
        case .commited:
            return nil
        case .pending:
            return style.statusStyleContainer.pending.icon
        case .rejected:
            return style.statusStyleContainer.rejected.icon
        }
    }
    
    func fetchText(for status: AssetTransactionStatus,
                   incoming: Bool,
                   style: TransactionCellStyleProtocol) -> String? {
        switch status {
        case .commited:
            return nil
        case .pending:
            return L10n.Status.textPending
        case .rejected:
            return L10n.Status.textRejected
        }
    }
}
