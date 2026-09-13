import XCTest
import AppKit
@testable import StatusItemKit

final class AppearanceMenuTests: XCTestCase {
    private func appearance() -> MeterAppearance {
        let defaults = UserDefaults(suiteName: "AppearanceMenuTests-\(UUID().uuidString)")!
        return MeterAppearance(defaults: defaults)
    }

    func testDefaultMenuOffersSharedPresetsAndCustomColour() {
        let menu = AppearanceMenu(appearance: appearance()) {}.menuItem().submenu!
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains("Custom Colour…"))
        XCTAssertTrue(titles.contains(MeterColor.presets[0].name))
    }

    // An app whose colour is not one number — a pair, a palette — supplies its
    // own block, and the shared presets and the panel stay out of its menu.
    func testColorItemsReplaceTheSharedColourBlock() {
        var built: NSMenu?
        let menu = AppearanceMenu(appearance: appearance(),
                                  colorItems: { submenu in
                                      built = submenu
                                      submenu.addItem(NSMenuItem(title: "Grape & Mint", action: nil, keyEquivalent: ""))
                                  }) {}.menuItem().submenu!
        XCTAssertTrue(built === menu)
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains("Grape & Mint"))
        XCTAssertFalse(titles.contains("Custom Colour…"))
        for preset in MeterColor.presets { XCTAssertFalse(titles.contains(preset.name)) }
        // Shapes still lead, separated from the colour block.
        XCTAssertEqual(titles.first, MeterStyle.proportional[0].title)
        XCTAssertTrue(menu.items.contains(where: \.isSeparatorItem))
    }
}
