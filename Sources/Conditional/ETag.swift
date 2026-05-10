// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

extension Conditional {
    /// An RFC 7232 § 2.3 entity-tag.
    ///
    /// Wire form is `"opaque"` (strong) or `W/"opaque"` (weak). Strong
    /// validators are byte-equivalent representations; weak ones permit
    /// semantic equivalence (e.g. compressed vs. uncompressed bodies).
    public struct ETag: Sendable, Equatable, Hashable {
        /// The opaque value between the surrounding double quotes — *not*
        /// percent-decoded; the wire format reserves only `"` and `\`.
        public let value: String
        /// `true` iff the wire token began with the `W/` prefix.
        public let isWeak: Bool

        public init(value: String, isWeak: Bool = false) {
            self.value = value
            self.isWeak = isWeak
        }

        /// Render the entity-tag in its wire form.
        public func serialized() -> String {
            isWeak ? "W/\"\(value)\"" : "\"\(value)\""
        }

        /// RFC 7232 § 2.3.2 strong comparison: both tags must be strong and
        /// have identical opaque values.
        public func strongMatches(_ other: ETag) -> Bool {
            !isWeak && !other.isWeak && value == other.value
        }

        /// RFC 7232 § 2.3.2 weak comparison: opaque values must be identical
        /// regardless of either tag's strength.
        public func weakMatches(_ other: ETag) -> Bool {
            value == other.value
        }
    }

    /// Parse a single `ETag:` response-header value.
    ///
    /// Accepts `"abc"` and `W/"abc"`. Surrounding whitespace is tolerated;
    /// the opaque body is not validated against the etagc range — callers
    /// that need to enforce US-ASCII visible characters can post-check.
    public static func parseETag(_ source: String) throws(ConditionalError) -> ETag {
        let trimmed = trimSP(source)
        var rest = Substring(trimmed)
        let weak = consumeWeakPrefix(&rest)
        guard let value = consumeQuoted(&rest), trimSP(String(rest)).isEmpty else {
            throw .malformedETag(source)
        }
        return ETag(value: value, isWeak: weak)
    }
}
