import XCTest
import AppKit
@testable import StatusItemKit

final class MenuBuilderTests: XCTestCase {
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    func testLabelWidthIsCeiledPlusBuffer() {
        let text = "▁▂▃▄▅▆▇█  100→200"
        let raw = (text as NSString).size(withAttributes: [.font: font]).width
        XCTAssertEqual(MenuBuilder.labelWidth(text, font: font, buffer: 4), ceil(raw) + 4, accuracy: 0.001)
    }

    func testLongerTextIsWider() {
        XCTAssertGreaterThan(
            MenuBuilder.labelWidth("longer string here", font: font),
            MenuBuilder.labelWidth("short", font: font)
        )
    }

    func testTextViewHasNonZeroExplicitFrame() {
        let v = MenuBuilder.textView("hello", font: font)
        XCTAssertGreaterThan(v.frame.width, 0)
        XCTAssertGreaterThan(v.frame.height, 0)
        XCTAssertEqual(v.subviews.count, 1)  // the label
    }
}
