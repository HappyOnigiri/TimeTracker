import Foundation
import SwiftData

/// 作業内容（TimeLog.notes）の文言をタグ単位で一括リネームする。
/// 部分文字列置換は行わず、完全一致したタグだけを置き換える。
enum WorkNoteRenaming {
    /// `old` に完全一致するタグを `new` に置き換えた配列を返す。置換対象がなければ nil。
    /// `old` / `new` は前後の空白を除いて比較し、置換後の値も空白を除いた形で保存する。
    /// 置換によって重複したタグは、最初の出現位置を残して除去する。
    static func renamed(notes: [String], from old: String, to new: String) -> [String]? {
        let oldKey = old.trimmingCharacters(in: .whitespacesAndNewlines)
        let newKey = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldKey.isEmpty, !newKey.isEmpty, oldKey != newKey else { return nil }

        var didReplace = false
        var seen: Set<String> = []
        var result: [String] = []
        for note in notes {
            let value: String
            if note.trimmingCharacters(in: .whitespacesAndNewlines) == oldKey {
                value = newKey
                didReplace = true
            } else {
                value = note
            }
            guard seen.insert(value).inserted else { continue }
            result.append(value)
        }
        return didReplace ? result : nil
    }

    /// 対象ログ群の notes を一括リネームし、変更されたログの件数を返す。
    /// 1 件も変更がなければ save しない。
    @discardableResult
    static func rename(from old: String, to new: String, in logs: [TimeLog], context: ModelContext) -> Int {
        var count = 0
        for log in logs {
            guard let updated = renamed(notes: log.notes, from: old, to: new) else { continue }
            log.notes = updated
            count += 1
        }
        if count > 0 {
            try? context.save()
        }
        return count
    }
}
