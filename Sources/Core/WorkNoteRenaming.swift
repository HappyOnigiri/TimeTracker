import Foundation
import SwiftData

/// 作業内容（TimeLog.notes）の文言をタグ単位で一括リネームする。
/// 部分文字列置換は行わず、完全一致したタグだけを置き換える。
enum WorkNoteRenaming {
    /// タグの比較に使う正規化。一致判定・重複判定はすべてこの値で行う。
    static func key(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `tag` に完全一致するタグを `notes` が含むか。`renamed` と同じ一致規則で判定する。
    static func matches(notes: [String], tag: String) -> Bool {
        let tagKey = key(tag)
        guard !tagKey.isEmpty else { return false }
        return notes.contains { key($0) == tagKey }
    }

    /// `old` に完全一致するタグを `new` に置き換えた配列を返す。置換対象がなければ nil。
    /// `old` / `new` は前後の空白を除いて比較し、置換後の値も空白を除いた形で保存する。
    /// 置換によって重複したタグは、最初の出現位置を残して除去する。
    static func renamed(notes: [String], from old: String, to new: String) -> [String]? {
        let oldKey = key(old)
        let newKey = key(new)
        guard !oldKey.isEmpty, !newKey.isEmpty, oldKey != newKey else { return nil }

        var didReplace = false
        var seen: Set<String> = []
        var result: [String] = []
        for note in notes {
            let value: String
            if key(note) == oldKey {
                value = newKey
                didReplace = true
            } else {
                value = note
            }
            // 重複判定も正規化後の値で行う（表記だけ違う重複を残さない）。
            guard seen.insert(key(value)).inserted else { continue }
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
