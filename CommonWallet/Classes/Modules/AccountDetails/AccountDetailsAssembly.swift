import Foundation


final class AccountDetailsAssembly: AccountDetailsAssemblyProtocol {
    static func assembleView(with resolver: ResolverProtocol, asset: WalletAsset) -> AccountDetailsViewProtocol? {
        let view = AccountDetailsViewController()
        view.controller.title = "Account Details"
        view.style = resolver.style

        guard
            let accountListView = AccountListAssembly.assembleView(with: resolver, detailsAsset: asset),
            let historyView = HistoryAssembly.assembleView(with: resolver, assets: [asset], type: .hidden) else {
                return nil
        }

        view.content = accountListView
        view.draggable = historyView

        let coordinator = AccountDetailsCoordinator()

        let presenter = AccountDetailsPresenter(view: view, coordinator: coordinator)
        view.presenter = presenter

        return view
    }
}
