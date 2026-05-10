// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Time

extension Conditional {
    /// Parse an `If-Modified-Since:` / `If-Unmodified-Since:` /
    /// `Last-Modified:` value as RFC 1123 date-time, returning a wall-clock
    /// `Time.Calendar` value.
    ///
    /// RFC 7231 § 7.1.1.1 allows three formats; we accept the preferred
    /// IMF-fixdate form via swift-time and surface the underlying parse
    /// error as `.malformedDate(_)`.
    public static func parseHTTPDate(_ source: String) throws(ConditionalError) -> Calendar {
        do {
            return try RFC1123.parse(source)
        } catch {
            throw .malformedDate(source)
        }
    }

    /// Serialize a `Time.Calendar` back to RFC 1123 IMF-fixdate.
    public static func serializeHTTPDate(_ calendar: Calendar) -> String {
        RFC1123.serialize(calendar)
    }
}
