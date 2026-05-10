// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

extension Conditional {
    /// Trim leading/trailing SP and HTAB per RFC 7230 OWS rules.
    static func trimSP(_ s: String) -> String {
        var i = s.startIndex
        var j = s.endIndex
        while i < j, s[i] == " " || s[i] == "\t" { i = s.index(after: i) }
        while j > i {
            let prev = s.index(before: j)
            let c = s[prev]
            if c != " " && c != "\t" { break }
            j = prev
        }
        return String(s[i..<j])
    }

    /// Skip OWS in a substring slice.
    static func skipOWS(_ s: inout Substring) {
        while let c = s.first, c == " " || c == "\t" {
            s = s.dropFirst()
        }
    }

    /// Consume a leading `W/` (case-sensitive per RFC 7232 § 2.3) and
    /// return whether it was present.
    static func consumeWeakPrefix(_ s: inout Substring) -> Bool {
        if s.hasPrefix("W/") {
            s = s.dropFirst(2)
            return true
        }
        return false
    }

    /// Consume `DQUOTE *etagc DQUOTE` from the front of `s`. The body may
    /// contain backslash-escapes per RFC 7230 quoted-string; we collapse
    /// `\X` to `X`. Returns `nil` if the input doesn't begin with a quote
    /// or the closing quote is missing.
    static func consumeQuoted(_ s: inout Substring) -> String? {
        guard s.first == "\"" else { return nil }
        var i = s.index(after: s.startIndex)
        var out = ""
        while i < s.endIndex {
            let c = s[i]
            if c == "\\" {
                let next = s.index(after: i)
                if next < s.endIndex {
                    out.append(s[next])
                    i = s.index(after: next)
                    continue
                } else {
                    return nil
                }
            }
            if c == "\"" {
                s = s[s.index(after: i)..<s.endIndex]
                return out
            }
            out.append(c)
            i = s.index(after: i)
        }
        return nil
    }
}
