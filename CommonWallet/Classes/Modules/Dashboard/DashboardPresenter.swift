import Foundation

final class DashboardPresenter {
    weak var view: DashboardViewProtocol?
    var coordinator: DashboardCoordinatorProtocol

    init(view: DashboardViewProtocol, coordinator: DashboardCoordinatorProtocol) {
        self.view = view
        self.coordinator = coordinator
    }
}

extension DashboardPresenter: DashboardPresenterProtocol {
    func reload() {}
}
