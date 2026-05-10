// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Time

extension Conditional {
    /// Snapshot of the conditional headers a server cares about for one
    /// incoming request.
    public struct Request: Sendable, Equatable {
        /// The HTTP method. Only the GET/HEAD distinction is load-bearing
        /// for evaluation, but the full method is preserved for clarity.
        public let method: String
        public let ifMatch: ETagList?
        public let ifNoneMatch: ETagList?
        public let ifModifiedSince: Calendar?
        public let ifUnmodifiedSince: Calendar?

        public init(
            method: String,
            ifMatch: ETagList? = nil,
            ifNoneMatch: ETagList? = nil,
            ifModifiedSince: Calendar? = nil,
            ifUnmodifiedSince: Calendar? = nil
        ) {
            self.method = method
            self.ifMatch = ifMatch
            self.ifNoneMatch = ifNoneMatch
            self.ifModifiedSince = ifModifiedSince
            self.ifUnmodifiedSince = ifUnmodifiedSince
        }
    }

    /// State of the resource the request is targeting.
    public struct Resource: Sendable, Equatable {
        /// The current entity-tag, if the resource has one.
        public let etag: ETag?
        /// The wall-clock `Last-Modified` value, if known.
        public let lastModified: Calendar?
        /// `false` when the request would be creating a new resource —
        /// affects the wildcard handling of `If-Match` / `If-None-Match`.
        public let exists: Bool

        public init(etag: ETag? = nil, lastModified: Calendar? = nil, exists: Bool = true) {
            self.etag = etag
            self.lastModified = lastModified
            self.exists = exists
        }
    }

    /// Outcome of evaluating preconditions against a resource.
    public enum Outcome: Sendable, Equatable {
        /// All preconditions hold; the request handler may proceed normally.
        case proceed
        /// `If-None-Match` / `If-Modified-Since` indicate the cached copy is
        /// fresh. Server should respond `304 Not Modified` (GET / HEAD only).
        case notModified
        /// One of the preconditions failed. Server should respond
        /// `412 Precondition Failed`.
        case preconditionFailed
    }

    /// Evaluate a request's RFC 7232 § 6 precondition ladder against a
    /// resource snapshot.
    ///
    /// Steps implemented (Range — step 5 — is delegated to swift-range):
    /// 1. `If-Match` present → strong-match the resource ETag, else 412.
    /// 2. `If-Unmodified-Since` present (and step 1 absent) → 412 if
    ///    the resource was modified later than the supplied instant.
    /// 3. `If-None-Match` present → weak-match the resource ETag.
    ///    GET/HEAD on a hit → 304; other methods on a hit → 412.
    /// 4. `If-Modified-Since` (GET/HEAD only, step 3 absent) → 304 when
    ///    the resource has not been modified since.
    public static func evaluate(_ request: Request, against resource: Resource) -> Outcome {
        let isReadOnly = isReadOnly(method: request.method)

        // Step 1: If-Match.
        if let ifMatch = request.ifMatch {
            if !matches(ifMatch, resource: resource, weak: false) {
                return .preconditionFailed
            }
        } else if let ius = request.ifUnmodifiedSince,
                  let lm = resource.lastModified {
            // Step 2: If-Unmodified-Since (only when If-Match absent).
            if compareSeconds(lm, ius) > 0 {
                return .preconditionFailed
            }
        }

        // Step 3: If-None-Match.
        if let ifNoneMatch = request.ifNoneMatch {
            if matches(ifNoneMatch, resource: resource, weak: true) {
                return isReadOnly ? .notModified : .preconditionFailed
            }
        } else if isReadOnly,
                  let ims = request.ifModifiedSince,
                  let lm = resource.lastModified {
            // Step 4: If-Modified-Since (read-only, If-None-Match absent).
            if compareSeconds(lm, ims) <= 0 {
                return .notModified
            }
        }

        return .proceed
    }

    static func isReadOnly(method: String) -> Bool {
        switch method.uppercased() {
        case "GET", "HEAD": return true
        default: return false
        }
    }

    /// Resolve an `ETagList` against the resource. `weak == true` uses
    /// weak comparison (for `If-None-Match`); `weak == false` uses strong
    /// comparison (for `If-Match`).
    static func matches(_ list: ETagList, resource: Resource, weak: Bool) -> Bool {
        switch list {
        case .any:
            return resource.exists
        case .list(let tags):
            guard let etag = resource.etag else { return false }
            for candidate in tags {
                if weak {
                    if candidate.weakMatches(etag) { return true }
                } else {
                    if candidate.strongMatches(etag) { return true }
                }
            }
            return false
        }
    }

    /// Compare two HTTP-date calendar values at one-second resolution.
    /// Returns -1 / 0 / +1. RFC 7232 deliberately ignores sub-second
    /// precision; ETag covers the finer-grained case. If either input
    /// fails calendar validation we fall back to "equal" — preconditions
    /// then evaluate optimistically rather than 412'ing the client over a
    /// server-side parse mismatch.
    static func compareSeconds(_ a: Calendar, _ b: Calendar) -> Int {
        guard let lhs = try? a.toInstant(), let rhs = try? b.toInstant() else {
            return 0
        }
        if lhs < rhs { return -1 }
        if lhs > rhs { return 1 }
        return 0
    }
}
