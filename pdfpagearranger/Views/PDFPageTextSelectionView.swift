import PDFKit
import SwiftUI

private final class NonScrollingPDFTextSelectionView: PDFView {
    override func layoutSubviews() {
        super.layoutSubviews()
        disableInternalScrolling(in: self)
    }

    private func disableInternalScrolling(in view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.isScrollEnabled = false
            scrollView.bounces = false
            scrollView.alwaysBounceHorizontal = false
            scrollView.alwaysBounceVertical = false
            scrollView.panGestureRecognizer.isEnabled = false
            scrollView.pinchGestureRecognizer?.isEnabled = false
        }

        for subview in view.subviews {
            disableInternalScrolling(in: subview)
        }
    }
}

struct PDFPageTextSelectionView: UIViewRepresentable {
    let page: PDFPage
    let pageRotation: Int
    let pageLoadKey: String
    let displaySize: CGSize
    let isInteractionEnabled: Bool
    let pageSwipeEnabled: Bool
    let onPageSwipe: ((PageModeNavigationDirection) -> Void)?
    let clearSelectionToken: UUID
    let onSelectionChange: (PDFTextSelection?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChange: onSelectionChange, onPageSwipe: onPageSwipe)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = NonScrollingPDFTextSelectionView()
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.pageBreakMargins = .zero
        pdfView.pageShadowsEnabled = false
        pdfView.backgroundColor = .clear
        pdfView.delegate = context.coordinator
        configureInteraction(for: pdfView)
        context.coordinator.pdfView = pdfView
        context.coordinator.installPageSwipeRecognizers(on: pdfView)
        context.coordinator.applyPageLoad(
            page: page,
            pageRotation: pageRotation,
            pageLoadKey: pageLoadKey
        )
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onPageSwipe = onPageSwipe
        context.coordinator.pageSwipeEnabled = pageSwipeEnabled
        context.coordinator.displaySize = displaySize
        configureInteraction(for: pdfView)

        if context.coordinator.loadedPageLoadKey != pageLoadKey {
            context.coordinator.applyPageLoad(
                page: page,
                pageRotation: pageRotation,
                pageLoadKey: pageLoadKey
            )
        }

        if context.coordinator.lastClearToken != clearSelectionToken {
            context.coordinator.lastClearToken = clearSelectionToken
            if pdfView.document != nil {
                pdfView.currentSelection = nil
            }
        }
    }

    static func dismantleUIView(_ pdfView: PDFView, coordinator: Coordinator) {
        pdfView.delegate = nil
        pdfView.document = nil
        coordinator.pdfView = nil
        coordinator.activePage = nil
    }

    private func configureInteraction(for pdfView: PDFView) {
        pdfView.isUserInteractionEnabled = isInteractionEnabled
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        (pdfView as? NonScrollingPDFTextSelectionView)?.setNeedsLayout()
    }

    final class Coordinator: NSObject, PDFViewDelegate, UIGestureRecognizerDelegate {
        var onSelectionChange: (PDFTextSelection?) -> Void
        var onPageSwipe: ((PageModeNavigationDirection) -> Void)?
        var pageSwipeEnabled = false
        weak var pdfView: PDFView?
        var activePage: PDFPage?
        var displaySize: CGSize = .zero
        var loadedPageLoadKey: String?
        var lastClearToken: UUID?
        private var installedSwipeRecognizers = false

        init(
            onSelectionChange: @escaping (PDFTextSelection?) -> Void,
            onPageSwipe: ((PageModeNavigationDirection) -> Void)?
        ) {
            self.onSelectionChange = onSelectionChange
            self.onPageSwipe = onPageSwipe
        }

        func applyPageLoad(page: PDFPage, pageRotation: Int, pageLoadKey: String) {
            guard let pdfView else { return }

            loadedPageLoadKey = pageLoadKey
            activePage = nil
            pdfView.currentSelection = nil

            guard let pageCopy = page.copy() as? PDFPage else {
                pdfView.document = nil
                return
            }

            pageCopy.rotation = pageRotation
            let document = PDFDocument()
            document.insert(pageCopy, at: 0)
            pdfView.document = document
            activePage = pageCopy
        }

        func installPageSwipeRecognizers(on pdfView: PDFView) {
            guard !installedSwipeRecognizers else { return }
            installedSwipeRecognizers = true

            let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handlePageSwipe(_:)))
            leftSwipe.direction = .left
            leftSwipe.delegate = self
            leftSwipe.cancelsTouchesInView = false
            pdfView.addGestureRecognizer(leftSwipe)

            let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handlePageSwipe(_:)))
            rightSwipe.direction = .right
            rightSwipe.delegate = self
            rightSwipe.cancelsTouchesInView = false
            pdfView.addGestureRecognizer(rightSwipe)
        }

        @objc private func handlePageSwipe(_ recognizer: UISwipeGestureRecognizer) {
            guard pageSwipeEnabled else { return }
            switch recognizer.direction {
            case .left:
                onPageSwipe?(.next)
            case .right:
                onPageSwipe?(.previous)
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func pdfViewSelectionChanged(_ sender: PDFView) {
            guard sender === pdfView else { return }
            guard let selection = sender.currentSelection,
                  let page = activePage ?? selection.pages.first else {
                onSelectionChange(nil)
                return
            }

            onSelectionChange(
                PDFTextSelectionEngine.makeTextSelection(
                    from: selection,
                    page: page,
                    displaySize: displaySize
                )
            )
        }
    }
}
