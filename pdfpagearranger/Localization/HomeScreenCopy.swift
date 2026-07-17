import Foundation

/// Localized copy for the empty-state Home screen.
enum HomeScreenCopy {
    static let appTitle = String(localized: "home.appTitle")
    static let subtitle = String(localized: "home.subtitle")
    static let openDocument = String(localized: "home.openDocument")
    static let createDocument = String(localized: "home.createDocument")
    static let scanToPDF = String(localized: "home.scanToPDF")
    static let photoToPDF = String(localized: "home.photoToPDF")
    static let recentDocuments = String(localized: "home.recentDocuments")
    static let recentDocumentsMore = String(localized: "home.recentDocuments.more")
    static let recentDocumentsEmpty = String(localized: "home.recentDocuments.empty")
    static let recentDocumentsUnavailable = String(localized: "home.recentDocuments.unavailable")

    static let openDocumentAccessibilityHint = String(localized: "home.openDocument.accessibilityHint")
    static let createDocumentAccessibilityHint = String(localized: "home.createDocument.accessibilityHint")
    static let scanToPDFAccessibilityHint = String(localized: "home.scanToPDF.accessibilityHint")
    static let photoToPDFAccessibilityHint = String(localized: "home.photoToPDF.accessibilityHint")
    static let recentDocumentsMoreAccessibilityHint = String(localized: "home.recentDocuments.more.accessibilityHint")

    /// Legacy aliases kept for gradual call-site migration in tests.
    static let openPDF = openDocument
    static let openPDFAccessibilityHint = openDocumentAccessibilityHint
}
