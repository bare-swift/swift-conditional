// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

extension Conditional {
    /// `If-Match:` / `If-None-Match:` request-header value.
    ///
    /// RFC 7232 § 3.1 / § 3.2 allow either the wildcard `*` (matches any
    /// representation) or a comma-separated list of `entity-tag` values.
    public enum ETagList: Sendable, Equatable {
        /// The literal `*` wildcard.
        case any
        /// One or more entity tags. Order is preserved as a parsing artefact;
        /// matching is set-membership and does not depend on it.
        case list([ETag])
    }

    /// Parse an `If-Match:` / `If-None-Match:` value.
    ///
    /// Empty input is rejected with `.malformedHeader` — RFC 7232 requires at
    /// least one entity-tag if the header is present at all.
    public static func parseETagList(_ source: String) throws(ConditionalError) -> ETagList {
        let trimmed = trimSP(source)
        if trimmed.isEmpty {
            throw .malformedHeader(source)
        }
        if trimmed == "*" {
            return .any
        }
        var s = Substring(trimmed)
        var tags: [ETag] = []
        while true {
            skipOWS(&s)
            let weak = consumeWeakPrefix(&s)
            guard let value = consumeQuoted(&s) else {
                throw .malformedETag(source)
            }
            tags.append(ETag(value: value, isWeak: weak))
            skipOWS(&s)
            if s.isEmpty { break }
            guard s.first == "," else {
                throw .malformedHeader(source)
            }
            s = s.dropFirst()
            skipOWS(&s)
            if s.isEmpty {
                throw .malformedHeader(source)
            }
        }
        if tags.isEmpty {
            throw .malformedHeader(source)
        }
        return .list(tags)
    }

    /// Render the list back to its wire form.
    public static func serializeETagList(_ list: ETagList) -> String {
        switch list {
        case .any:
            return "*"
        case .list(let tags):
            var out = ""
            for (i, tag) in tags.enumerated() {
                if i > 0 { out.append(", ") }
                out.append(tag.serialized())
            }
            return out
        }
    }
}
