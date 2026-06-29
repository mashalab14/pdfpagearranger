import SwiftUI

@Observable
final class OverlayManipulationState {
    private(set) var isActive = false

    func begin() {
        isActive = true
    }

    func end() {
        isActive = false
    }
}
