import Foundation

enum PageModeNavigationDirection: Equatable {
    case previous
    case next
}

enum PageModeNavigationEngine {
  static let minimumSwipeDistance: CGFloat = 60
  static let horizontalDominanceRatio: CGFloat = 1.35

  static func adjacentPageIndex(
    currentIndex: Int,
    pageCount: Int,
    direction: PageModeNavigationDirection
  ) -> Int? {
    guard currentIndex >= 0, currentIndex < pageCount, pageCount > 0 else { return nil }

    switch direction {
    case .previous:
      return currentIndex > 0 ? currentIndex - 1 : nil
    case .next:
      return currentIndex + 1 < pageCount ? currentIndex + 1 : nil
    }
  }

  static func shouldAllowPageSwipe(
    overlayManipulationActive: Bool,
    isPageZoomed: Bool
  ) -> Bool {
    !overlayManipulationActive && !isPageZoomed
  }

  static func direction(
    for translation: CGSize,
    minimumDistance: CGFloat = minimumSwipeDistance,
    horizontalDominanceRatio: CGFloat = horizontalDominanceRatio
  ) -> PageModeNavigationDirection? {
    let horizontal = abs(translation.width)
    let vertical = abs(translation.height)

    guard horizontal >= minimumDistance else { return nil }
    guard horizontal >= vertical * horizontalDominanceRatio else { return nil }

    return translation.width < 0 ? .next : .previous
  }
}
