/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol CommonWalletBuilderProtocol: class {
    static func builder(with account: WalletAccountSettingsProtocol,
                        networkResolver: WalletNetworkResolverProtocol) -> CommonWalletBuilderProtocol

    var accountListModuleBuilder: AccountListModuleBuilderProtocol { get }
    var historyModuleBuilder: HistoryModuleBuilderProtocol { get }
    var invoiceScanModuleBuilder: InvoiceScanModuleBuilderProtocol { get }
    var contactsModuleBuilder: ContactsModuleBuilderProtocol { get }
    var styleBuilder: WalletStyleBuilderProtocol { get }

    @discardableResult
    func with(amountFormatter: NumberFormatter) -> Self

    @discardableResult
    func with(historyDateFormatter: DateFormatter) -> Self

    @discardableResult
    func with(transferDescriptionLimit: UInt8) -> Self

    @discardableResult
    func with(transferAmountLimit: Decimal) -> Self

    @discardableResult
    func with(logger: WalletLoggerProtocol) -> Self
    
    @discardableResult
    func with(transactionTypeList: [WalletTransactionType]) -> Self

    @discardableResult
    func with(commandDecoratorFactory: WalletCommandDecoratorFactoryProtocol) -> Self

    @discardableResult
    func with(inputValidatorFactory: WalletInputValidatorFactoryProtocol) -> Self

    func build() throws -> CommonWalletContextProtocol
}

public enum CommonWalletBuilderError: Error {
    case moduleCreationFailed
}

public final class CommonWalletBuilder {
    fileprivate var privateAccountModuleBuilder: AccountListModuleBuilder
    fileprivate var privateHistoryModuleBuilder: HistoryModuleBuilder
    fileprivate var privateContactsModuleBuilder: ContactsModuleBuilder
    fileprivate var privateInvoiceScanModuleBuilder: InvoiceScanModuleBuilder
    fileprivate var privateStyleBuilder: WalletStyleBuilder
    fileprivate var account: WalletAccountSettingsProtocol
    fileprivate var networkResolver: WalletNetworkResolverProtocol
    fileprivate var logger: WalletLoggerProtocol?
    fileprivate var amountFormatter: NumberFormatter?
    fileprivate var historyDateFormatter: DateFormatter?
    fileprivate var transferDescriptionLimit: UInt8 = 64
    fileprivate var transferAmountLimit: Decimal?
    fileprivate var transactionTypeList: [WalletTransactionType]?
    fileprivate var commandDecoratorFactory: WalletCommandDecoratorFactoryProtocol?
    fileprivate var inputValidatorFactory: WalletInputValidatorFactoryProtocol?

    init(account: WalletAccountSettingsProtocol, networkResolver: WalletNetworkResolverProtocol) {
        self.account = account
        self.networkResolver = networkResolver
        privateAccountModuleBuilder = AccountListModuleBuilder()
        privateHistoryModuleBuilder = HistoryModuleBuilder()
        privateContactsModuleBuilder = ContactsModuleBuilder()
        privateInvoiceScanModuleBuilder = InvoiceScanModuleBuilder()
        privateStyleBuilder = WalletStyleBuilder()
    }
}

extension CommonWalletBuilder: CommonWalletBuilderProtocol {
    public var accountListModuleBuilder: AccountListModuleBuilderProtocol {
        return privateAccountModuleBuilder
    }

    public var historyModuleBuilder: HistoryModuleBuilderProtocol {
        return privateHistoryModuleBuilder
    }
    
    public var contactsModuleBuilder: ContactsModuleBuilderProtocol {
        return privateContactsModuleBuilder
    }

    public var invoiceScanModuleBuilder: InvoiceScanModuleBuilderProtocol {
        return privateInvoiceScanModuleBuilder
    }

    public var styleBuilder: WalletStyleBuilderProtocol {
        return privateStyleBuilder
    }

    public static func builder(with account: WalletAccountSettingsProtocol,
                               networkResolver: WalletNetworkResolverProtocol) -> CommonWalletBuilderProtocol {
        return CommonWalletBuilder(account: account, networkResolver: networkResolver)
    }

    public func with(amountFormatter: NumberFormatter) -> Self {
        self.amountFormatter = amountFormatter

        return self
    }

    public func with(historyDateFormatter: DateFormatter) -> Self {
        self.historyDateFormatter = historyDateFormatter

        return self
    }

    public func with(logger: WalletLoggerProtocol) -> Self {
        self.logger = logger
        return self
    }

    public func with(transferDescriptionLimit: UInt8) -> Self {
        self.transferDescriptionLimit = transferDescriptionLimit
        return self
    }

    public func with(transferAmountLimit: Decimal) -> Self {
        self.transferAmountLimit = transferAmountLimit
        return self
    }
    
    public func with(transactionTypeList: [WalletTransactionType]) -> Self {
        self.transactionTypeList = transactionTypeList
        return self
    }

    public func with(commandDecoratorFactory: WalletCommandDecoratorFactoryProtocol) -> Self {
        self.commandDecoratorFactory = commandDecoratorFactory
        return self
    }

    public func with(inputValidatorFactory: WalletInputValidatorFactoryProtocol) -> Self {
        self.inputValidatorFactory = inputValidatorFactory
        return self
    }

    public func build() throws -> CommonWalletContextProtocol {
        let style = privateStyleBuilder.build()

        privateAccountModuleBuilder.walletStyle = style
        let accountListConfiguration = try privateAccountModuleBuilder.build()

        privateHistoryModuleBuilder.walletStyle = style
        let historyConfiguration = privateHistoryModuleBuilder.build()

        privateContactsModuleBuilder.walletStyle = style
        let contactsConfiguration = privateContactsModuleBuilder.build()

        privateInvoiceScanModuleBuilder.walletStyle = style
        let invoiceScanConfiguration = privateInvoiceScanModuleBuilder.build()

        let decorator = WalletInputValidatorFactoryDecorator(descriptionMaxLength: transferDescriptionLimit)
        decorator.underlyingFactory = inputValidatorFactory

        let resolver = Resolver(account: account,
                                networkResolver: networkResolver,
                                accountListConfiguration: accountListConfiguration,
                                historyConfiguration: historyConfiguration,
                                contactsConfiguration: contactsConfiguration,
                                invoiceScanConfiguration: invoiceScanConfiguration,
                                inputValidatorFactory: decorator)

        resolver.commandDecoratorFactory = commandDecoratorFactory

        if let transferAmountLimit = transferAmountLimit {
            resolver.transferAmountLimit = transferAmountLimit
        }

        resolver.style = style

        resolver.logger = logger

        if let amountFormatter = amountFormatter {
            resolver.amountFormatter = amountFormatter
        }

        if let historyDateFormatter = historyDateFormatter {
            resolver.historyDateFormatter = historyDateFormatter
        }
        
        if let transactionTypeList = transactionTypeList {
            resolver.transactionTypeList = transactionTypeList
        }

        return resolver
    }
}
