import Foundation


final class AccountDetailsPresenter {
    weak var view: AccountDetailsViewProtocol?
    var coordinator: AccountDetailsCoordinatorProtocol

    init(view: AccountDetailsViewProtocol, coordinator: AccountDetailsCoordinatorProtocol) {
        self.view = view
        self.coordinator = coordinator
    }
}


extension AccountDetailsPresenter: AccountDetailsPresenterProtocol {
    func setup() {}
}