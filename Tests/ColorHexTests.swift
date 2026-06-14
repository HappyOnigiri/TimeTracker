import SwiftUI
import Testing
@testable import TimeTracker

struct ColorHexTests {
    @Test("有効な 16 進文字列から色を生成できる")
    func parsesValidHex() {
        #expect(Color(hex: "#FF8800") != nil)
        #expect(Color(hex: "34C759") != nil)
    }

    @Test("無効な文字列は nil を返す")
    func rejectsInvalidHex() {
        #expect(Color(hex: "#XYZ") == nil)
        #expect(Color(hex: "12345") == nil)
        #expect(Color(hex: "") == nil)
    }

    @Test("パレットは範囲外インデックスでも巡回する")
    func paletteWrapsAround() {
        let count = ProjectPalette.colors.count
        #expect(ProjectPalette.color(forIndex: 0) == ProjectPalette.color(forIndex: count))
        #expect(ProjectPalette.color(forIndex: -1) == ProjectPalette.color(forIndex: count - 1))
    }
}
