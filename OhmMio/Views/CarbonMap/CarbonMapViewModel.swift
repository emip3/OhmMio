//
//  CarbonMapViewModel.swift
//  OhmMio
//
//  Created by Emiliano Ruíz Plancarte on 05/05/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class CarbonMapViewModel {

    enum State {
        case loading
        case loaded([CarbonIntensity], nowHour: Int)
        case error(String)
    }

    var state: State = .loading

    func load() async {
        state = .loading
        do {
            let matrix = try CarbonIntensityService.dailyMatrix()
            let nowHour = Calendar.current.component(.hour, from: Date())
            state = .loaded(matrix, nowHour: nowHour)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
