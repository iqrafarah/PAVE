import PAVECore
import SwiftUI
import Testing
@testable import PAVE

struct AdaptiveModeTests {
    private let innerPortrait = CGSize(width: 669, height: 951)
    private let innerLandscape = CGSize(width: 951, height: 669)

    @Test func portraitStaysACardWhenTheKeyboardOpens() {
        let withKeyboard = CGSize(width: 669, height: 560)
        let mode = AdaptiveMode.resolve(size: withKeyboard, stableSize: innerPortrait, sizeClass: .regular, fold: nil)
        #expect(mode == .card)
    }

    @Test func portraitWithoutKeyboardIsACard() {
        let mode = AdaptiveMode.resolve(size: innerPortrait, stableSize: innerPortrait, sizeClass: .regular, fold: nil)
        #expect(mode == .card)
    }

    @Test func landscapeSplitsAndPlacesPanesInsideTheShrunkenSpace() {
        let withKeyboard = CGSize(width: 951, height: 400)
        let mode = AdaptiveMode.resolve(size: withKeyboard, stableSize: innerLandscape, sizeClass: .regular, fold: nil)
        #expect(mode == .split(.landscape(in: withKeyboard)))
    }

    @Test func compactWidthIsAlwaysCompact() {
        let wideButCompact = CGSize(width: 800, height: 300)
        let mode = AdaptiveMode.resolve(size: wideButCompact, stableSize: wideButCompact, sizeClass: .compact, fold: nil)
        #expect(mode == .compact)
    }

    @Test func foldWinsOverTheDefaultLayout() {
        let fold = FoldSplit(
            axis: .sideBySide,
            first: CGRect(x: 0, y: 0, width: 400, height: 669),
            second: CGRect(x: 500, y: 0, width: 451, height: 669)
        )
        let mode = AdaptiveMode.resolve(size: innerLandscape, stableSize: innerLandscape, sizeClass: .regular, fold: fold)
        #expect(mode == .split(fold))
    }
}
