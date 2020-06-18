/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation


public enum AssetTransactionStatus: String, Codable {
    case pending = "PENDING"
    case commited = "COMMITTED"
    case rejected = "REJECTED"
}


public struct AssetTransactionData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case transactionId
        case status
        case assetId
        case peerId
        case peerName
        case peerFirstName
        case peerLastName
        case details
        case amount
        case fee
        case timestamp
        case type
        case reason
    }

    public let transactionId: String
    public let status: AssetTransactionStatus
    public let assetId: String
    public let peerId: String
    public let peerFirstName: String?
    public let peerLastName: String?
    public let peerName: String?
    public let details: String
    public let amount: AmountDecimal
    public let fee: AmountDecimal?
    public let timestamp: Int64
    public let type: String
    public let reason: String?

    public init(transactionId: String,
                status: AssetTransactionStatus,
                assetId: String,
                peerId: String,
                peerFirstName: String?,
                peerLastName: String?,
                peerName: String?,
                details: String,
                amount: AmountDecimal,
                fee: AmountDecimal?,
                timestamp: Int64,
                type: String,
                reason: String?) {
        self.transactionId = transactionId
        self.status = status
        self.assetId = assetId
        self.peerId = peerId
        self.peerFirstName = peerFirstName
        self.peerLastName = peerLastName
        self.peerName = peerName
        self.details = details
        self.amount = amount
        self.fee = fee
        self.timestamp = timestamp
        self.type = type
        self.reason = reason
    }
}

public struct AssetTransactionPageData: Codable, Equatable {
    public let transactions: [AssetTransactionData]
    public let context: PaginationContext?

    public init(transactions: [AssetTransactionData],
                context: PaginationContext? = nil) {
        self.transactions = transactions
        self.context = context
    }
}
