// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

extension Conditional {
    /// Errors raised by `Conditional` parsers.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// The header value was structurally malformed (missing quotes, stray
        /// characters, empty entry where one was required, etc.).
        case malformedHeader(String)
        /// An ETag value or list contained a token that does not match the
        /// `entity-tag = [ "W/" ] DQUOTE *etagc DQUOTE` grammar.
        case malformedETag(String)
        /// An HTTP-date header could not be parsed under RFC 1123 rules.
        case malformedDate(String)
    }
}

/// Convenience alias matching the package's other error-typing conventions.
public typealias ConditionalError = Conditional.Error
