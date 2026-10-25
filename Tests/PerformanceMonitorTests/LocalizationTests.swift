import XCTest
@testable import PerformanceMonitor

final class LocalizationTests: XCTestCase {
    func testBothLanguagesResolveUIAndStatusLabels() {
        let samples = ["Processos": "Processes", "Memória": "Memory", "Ajustes": "Settings", "Executando": "Running", "Indisponível": "Unavailable", "Forçar encerramento": "Force quit", "Swap de saída:": "Swap out:"]
        for (portuguese, english) in samples {
            XCTAssertEqual(L10n.text(portuguese, language: .english), english)
            XCTAssertEqual(L10n.text(portuguese, language: .portuguese), portuguese)
        }
    }
    func testInterpolatedLabelsDoNotTreatValuesAsFormatStrings() {
        let disk: LocalizedMessage = "Disco \(3)"
        XCTAssertEqual(disk.resolved(language: .english), "Disk 3")
        XCTAssertEqual(disk.resolved(language: .portuguese), "Disco 3")
        let name = "Example %@ 100%"
        let message: LocalizedMessage = "Finalizar \(name)?"
        XCTAssertEqual(message.resolved(language: .english), "End Example %@ 100%?")
    }
    func testByteFormattingUsesSelectedLocale() {
        XCTAssertEqual(L10n.bytes(1.5 * 1024 * 1024, language: .english), "1.5 MB")
        XCTAssertEqual(L10n.bytes(1.5 * 1024 * 1024, language: .portuguese), "1,5 MB")
        XCTAssertEqual(L10n.bytes(0, language: .english), "0 B")
    }
    func testCatalogsHaveIdenticalKeysAndPlaceholderCounts() throws {
        func catalog(_ language: AppLanguage) throws -> [String: String] {
            let folder = try XCTUnwrap(Bundle.module.path(forResource: language.resource, ofType: "lproj"))
            let data = try Data(contentsOf: URL(fileURLWithPath: folder).appendingPathComponent("Localizable.strings"))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        let english = try catalog(.english)
        let portuguese = try catalog(.portuguese)
        XCTAssertGreaterThan(english.count, 150)
        XCTAssertEqual(Set(english.keys), Set(portuguese.keys))
        for (key, value) in english {
            XCTAssertEqual(key.components(separatedBy: "%@").count, value.components(separatedBy: "%@").count, key)
            XCTAssertFalse(value.isEmpty)
        }
    }
}
