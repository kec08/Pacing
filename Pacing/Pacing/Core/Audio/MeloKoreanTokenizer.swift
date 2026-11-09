import Foundation

/// The bundled lexicon contains g2pkk pronunciations for the running prompts and
/// their numeric units. It keeps Python and Mecab out of the iOS runtime.
struct MeloKoreanTokenizer {
    private static let numberWithUnit = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)(킬로미터|시간|분|초)"#
    )

    private let pronunciations: [String: [Int64]]

    init(pronunciations: [String: [Int64]]) {
        self.pronunciations = pronunciations
    }

    func tokenIDs(for text: String) -> [Int64]? {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = Self.numberWithUnit.matches(in: text, range: fullRange)
        var phones: [Int64] = [0]
        var cursor = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text),
                  let numberRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  appendLiteral(String(text[cursor..<range.lowerBound]), to: &phones),
                  appendNumber(String(text[numberRange]), unit: String(text[unitRange]), to: &phones)
            else { return nil }
            cursor = range.upperBound
        }

        guard appendLiteral(String(text[cursor...]), to: &phones), phones.count > 2 else { return nil }
        phones.append(0)

        var input: [Int64] = []
        input.reserveCapacity(phones.count * 2 - 1)
        for (index, phone) in phones.enumerated() {
            if index > 0 { input.append(0) }
            input.append(phone)
        }
        return input
    }

    private func appendLiteral(_ literal: String, to phones: inout [Int64]) -> Bool {
        let key = literal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return true }
        guard let value = pronunciations[key] else { return false }
        phones.append(contentsOf: value)
        return true
    }

    private func appendNumber(_ number: String, unit: String, to phones: inout [Int64]) -> Bool {
        if number.contains(".") {
            let parts = number.split(separator: ".", omittingEmptySubsequences: false)
            guard unit == "킬로미터", parts.count == 2, parts[1].count == 2,
                  let integer = Int(parts[0]), integer < 1_000,
                  let integerPhones = pronunciations["__number_\(integer)"],
                  let pointPhones = pronunciations["점"],
                  let unitPhones = pronunciations[unit]
            else { return false }
            phones.append(contentsOf: integerPhones)
            phones.append(contentsOf: pointPhones)
            for digit in parts[1] {
                guard let digitPhones = pronunciations["__number_\(digit)"] else { return false }
                phones.append(contentsOf: digitPhones)
            }
            phones.append(contentsOf: unitPhones)
            return true
        }

        guard let value = pronunciations["\(number)\(unit)"] else { return false }
        phones.append(contentsOf: value)
        return true
    }
}
