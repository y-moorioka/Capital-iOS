/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation


protocol PickerPresentable: class {

    func presentPicker(for titles: [String], initialIndex: Int, delegate: ModalPickerViewDelegate?)
    func presentDatePicker(for minDate: Date?, maxDate: Date?, delegate: ModalDatePickerViewDelegate?)

}


extension PickerPresentable where Self: CoordinatorProtocol {

    func presentPicker(for titles: [String], initialIndex: Int, delegate: ModalPickerViewDelegate?) {
        guard let view = ModalPickerViewFactory.createView(with: titles,
                                                           initialIndex: initialIndex,
                                                           delegate: delegate,
                                                           style: resolver.style) else {
            return
        }

        resolver.navigation.present(view.controller)
    }
    
    func presentDatePicker(for minDate: Date?, maxDate: Date?, delegate: ModalDatePickerViewDelegate?) {
        guard let view = ModalDatePickerViewFactory.createView(with: minDate,
                                                               maxDate: maxDate,
                                                               delegate: delegate,
                                                               style: resolver.style) else {
            return
        }
        
        resolver.navigation.present(view.controller)
    }

}
