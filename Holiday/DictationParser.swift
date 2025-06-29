import Foundation

struct ParsedEvent {
    let date: Date?
    let title: String
    let note: String
}

func parseEvent(from text: String, maxTitleWords: Int = 6) -> ParsedEvent {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    let matches  = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []

    var foundDate: Date?
    var cleared  = text

    if let m = matches.first, let d = m.date, let r = Range(m.range, in: text) {
        foundDate = d
        cleared.removeSubrange(r)
    }

    let words      = cleared.split(separator: " ").map(String.init)
    let titleWords = words.prefix(maxTitleWords)
    let noteWords  = words.dropFirst(maxTitleWords)

    return ParsedEvent(
        date:  foundDate,
        title: titleWords.joined(separator: " ").trimmingCharacters(in: .whitespaces),
        note:  noteWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    )
}

struct DictationDraft: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var date: Date
    var note: String
    var hasTime: Bool
}

func parseDictation(_ text: String, maxTitleWords: Int = 6) -> DictationDraft {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    let range = NSRange(text.startIndex..., in: text)
    let match = detector?.firstMatch(in: text, options: [], range: range)

    var foundDate: Date?
    var cleared = text

    if let m = match, let d = m.date, let r = Range(m.range, in: text) {
        foundDate = d
        cleared.removeSubrange(r)
    }

    let words = cleared.split(separator: " ").map(String.init)
    let titleWords = words.prefix(maxTitleWords)
    let noteWords = words.dropFirst(maxTitleWords)

    let title = titleWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    let note  = noteWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)

    let comps = Calendar.current.dateComponents([.hour, .minute], from: foundDate ?? Date())
    let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0

    return DictationDraft(
        title: title.isEmpty ? text : title,
        date: foundDate ?? Date(),
        note: note,
        hasTime: hasTime
    )
}
