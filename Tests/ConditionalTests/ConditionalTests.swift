// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
import Time
@testable import Conditional

// MARK: - ETag

@Suite("ETag parse + serialize")
struct ETagSuite {
    @Test("strong tag round-trip")
    func strongRoundTrip() throws {
        let tag = try Conditional.parseETag("\"xyzzy\"")
        #expect(tag.value == "xyzzy")
        #expect(tag.isWeak == false)
        #expect(tag.serialized() == "\"xyzzy\"")
    }

    @Test("weak tag round-trip")
    func weakRoundTrip() throws {
        let tag = try Conditional.parseETag("W/\"abc-1\"")
        #expect(tag.value == "abc-1")
        #expect(tag.isWeak == true)
        #expect(tag.serialized() == "W/\"abc-1\"")
    }

    @Test("surrounding whitespace tolerated")
    func surroundingWhitespace() throws {
        let tag = try Conditional.parseETag("   \"abc\"   ")
        #expect(tag.value == "abc")
    }

    @Test("empty body permitted (rare but legal)")
    func emptyBody() throws {
        let tag = try Conditional.parseETag("\"\"")
        #expect(tag.value == "")
        #expect(tag.isWeak == false)
    }

    @Test("backslash escape collapses one character")
    func backslashEscape() throws {
        let tag = try Conditional.parseETag("\"a\\\"b\"")
        #expect(tag.value == "a\"b")
    }

    @Test("missing quotes fails")
    func missingQuotes() {
        #expect(throws: ConditionalError.self) {
            _ = try Conditional.parseETag("xyzzy")
        }
    }

    @Test("trailing garbage fails")
    func trailingGarbage() {
        #expect(throws: ConditionalError.self) {
            _ = try Conditional.parseETag("\"xyzzy\" extra")
        }
    }

    @Test("strong vs weak comparison")
    func strongVsWeak() {
        let strong = Conditional.ETag(value: "1", isWeak: false)
        let weak = Conditional.ETag(value: "1", isWeak: true)
        let other = Conditional.ETag(value: "2", isWeak: false)
        #expect(strong.strongMatches(strong))
        #expect(!strong.strongMatches(weak))
        #expect(!weak.strongMatches(weak))
        #expect(strong.weakMatches(weak))
        #expect(weak.weakMatches(strong))
        #expect(!strong.weakMatches(other))
    }
}

// MARK: - ETagList

@Suite("ETagList parse + serialize")
struct ETagListSuite {
    @Test("wildcard")
    func wildcard() throws {
        let list = try Conditional.parseETagList("*")
        #expect(list == .any)
        #expect(Conditional.serializeETagList(list) == "*")
    }

    @Test("single tag")
    func single() throws {
        let list = try Conditional.parseETagList("\"abc\"")
        guard case .list(let tags) = list else {
            Issue.record("expected list")
            return
        }
        #expect(tags == [Conditional.ETag(value: "abc")])
    }

    @Test("two tags with mixed strength")
    func mixed() throws {
        let list = try Conditional.parseETagList("\"a\", W/\"b\"")
        guard case .list(let tags) = list else {
            Issue.record("expected list")
            return
        }
        #expect(tags == [
            Conditional.ETag(value: "a", isWeak: false),
            Conditional.ETag(value: "b", isWeak: true),
        ])
    }

    @Test("whitespace tolerated around commas")
    func whitespace() throws {
        let list = try Conditional.parseETagList("  \"a\"  ,  \"b\"  ,\t\"c\" ")
        guard case .list(let tags) = list else {
            Issue.record("expected list")
            return
        }
        #expect(tags.count == 3)
    }

    @Test("round-trip three tags")
    func roundTrip() throws {
        let original = "\"a\", W/\"b\", \"c\""
        let list = try Conditional.parseETagList(original)
        #expect(Conditional.serializeETagList(list) == original)
    }

    @Test("empty input rejected")
    func empty() {
        #expect(throws: ConditionalError.self) {
            _ = try Conditional.parseETagList("")
        }
    }

    @Test("trailing comma without tag rejected")
    func trailingComma() {
        #expect(throws: ConditionalError.self) {
            _ = try Conditional.parseETagList("\"a\",")
        }
    }

    @Test("missing comma rejected")
    func missingComma() {
        #expect(throws: ConditionalError.self) {
            _ = try Conditional.parseETagList("\"a\" \"b\"")
        }
    }
}

// MARK: - HTTPDate

@Suite("HTTP-date parse + serialize")
struct HTTPDateSuite {
    @Test("RFC 1123 round-trip")
    func roundTrip() throws {
        let s = "Sun, 06 Nov 1994 08:49:37 GMT"
        let cal = try Conditional.parseHTTPDate(s)
        #expect(cal.year == 1994)
        #expect(cal.month == 11)
        #expect(cal.day == 6)
        #expect(cal.hour == 8)
        #expect(cal.minute == 49)
        #expect(cal.second == 37)
        #expect(Conditional.serializeHTTPDate(cal) == s)
    }

    @Test("malformed date rejected as ConditionalError")
    func malformed() {
        #expect(throws: ConditionalError.self) {
            _ = try Conditional.parseHTTPDate("not a date")
        }
    }
}

// MARK: - Evaluator

@Suite("Precondition evaluator (RFC 7232 § 6)")
struct EvaluatorSuite {
    /// Helper: build a Calendar at GMT with second-resolution.
    static func gmt(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Calendar {
        Calendar(year: y, month: mo, day: d, hour: h, minute: mi, second: s, nanosecond: 0, offsetSeconds: 0)
    }

    let resourceETag = Conditional.ETag(value: "v1")
    let resourceModified = EvaluatorSuite.gmt(2024, 1, 1, 12, 0, 0)

    var resource: Conditional.Resource {
        Conditional.Resource(etag: resourceETag, lastModified: resourceModified, exists: true)
    }

    // --- Step 1: If-Match ---

    @Test("If-Match strong hit → proceed")
    func ifMatchHit() {
        let req = Conditional.Request(
            method: "PUT",
            ifMatch: .list([resourceETag])
        )
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }

    @Test("If-Match miss → 412")
    func ifMatchMiss() {
        let req = Conditional.Request(
            method: "PUT",
            ifMatch: .list([Conditional.ETag(value: "other")])
        )
        #expect(Conditional.evaluate(req, against: resource) == .preconditionFailed)
    }

    @Test("If-Match weak tag never strong-matches")
    func ifMatchWeakNeverMatches() {
        let req = Conditional.Request(
            method: "PUT",
            ifMatch: .list([Conditional.ETag(value: "v1", isWeak: true)])
        )
        #expect(Conditional.evaluate(req, against: resource) == .preconditionFailed)
    }

    @Test("If-Match * on existing resource → proceed")
    func ifMatchAnyExists() {
        let req = Conditional.Request(method: "PUT", ifMatch: .any)
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }

    @Test("If-Match * on missing resource → 412")
    func ifMatchAnyMissing() {
        let req = Conditional.Request(method: "PUT", ifMatch: .any)
        let missing = Conditional.Resource(etag: nil, lastModified: nil, exists: false)
        #expect(Conditional.evaluate(req, against: missing) == .preconditionFailed)
    }

    // --- Step 2: If-Unmodified-Since ---

    @Test("If-Unmodified-Since after Last-Modified → proceed")
    func ifUnmodifiedSinceProceed() {
        let req = Conditional.Request(
            method: "PUT",
            ifUnmodifiedSince: EvaluatorSuite.gmt(2024, 6, 1, 0, 0, 0)
        )
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }

    @Test("If-Unmodified-Since before Last-Modified → 412")
    func ifUnmodifiedSinceFailed() {
        let req = Conditional.Request(
            method: "PUT",
            ifUnmodifiedSince: EvaluatorSuite.gmt(2023, 1, 1, 0, 0, 0)
        )
        #expect(Conditional.evaluate(req, against: resource) == .preconditionFailed)
    }

    @Test("If-Match present suppresses If-Unmodified-Since")
    func ifMatchSuppresses() {
        let req = Conditional.Request(
            method: "PUT",
            ifMatch: .list([resourceETag]),
            ifUnmodifiedSince: EvaluatorSuite.gmt(2023, 1, 1, 0, 0, 0)
        )
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }

    // --- Step 3: If-None-Match ---

    @Test("If-None-Match hit on GET → 304")
    func ifNoneMatchGetHit() {
        let req = Conditional.Request(
            method: "GET",
            ifNoneMatch: .list([resourceETag])
        )
        #expect(Conditional.evaluate(req, against: resource) == .notModified)
    }

    @Test("If-None-Match hit on PUT → 412")
    func ifNoneMatchPutHit() {
        let req = Conditional.Request(
            method: "PUT",
            ifNoneMatch: .list([resourceETag])
        )
        #expect(Conditional.evaluate(req, against: resource) == .preconditionFailed)
    }

    @Test("If-None-Match miss → proceed")
    func ifNoneMatchMiss() {
        let req = Conditional.Request(
            method: "GET",
            ifNoneMatch: .list([Conditional.ETag(value: "other")])
        )
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }

    @Test("If-None-Match weak comparison: weak tag matches strong resource")
    func ifNoneMatchWeak() {
        let req = Conditional.Request(
            method: "GET",
            ifNoneMatch: .list([Conditional.ETag(value: "v1", isWeak: true)])
        )
        #expect(Conditional.evaluate(req, against: resource) == .notModified)
    }

    @Test("If-None-Match * on existing resource for GET → 304")
    func ifNoneMatchAnyGet() {
        let req = Conditional.Request(method: "GET", ifNoneMatch: .any)
        #expect(Conditional.evaluate(req, against: resource) == .notModified)
    }

    @Test("If-None-Match * on missing resource → proceed (idempotent create)")
    func ifNoneMatchAnyMissing() {
        let req = Conditional.Request(method: "PUT", ifNoneMatch: .any)
        let missing = Conditional.Resource(etag: nil, lastModified: nil, exists: false)
        #expect(Conditional.evaluate(req, against: missing) == .proceed)
    }

    // --- Step 4: If-Modified-Since ---

    @Test("If-Modified-Since after Last-Modified → 304")
    func ifModifiedSinceFresh() {
        let req = Conditional.Request(
            method: "GET",
            ifModifiedSince: EvaluatorSuite.gmt(2024, 6, 1, 0, 0, 0)
        )
        #expect(Conditional.evaluate(req, against: resource) == .notModified)
    }

    @Test("If-Modified-Since before Last-Modified → proceed")
    func ifModifiedSinceStale() {
        let req = Conditional.Request(
            method: "GET",
            ifModifiedSince: EvaluatorSuite.gmt(2023, 1, 1, 0, 0, 0)
        )
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }

    @Test("If-Modified-Since equal to Last-Modified → 304 (lm <= ims)")
    func ifModifiedSinceEqual() {
        let req = Conditional.Request(
            method: "GET",
            ifModifiedSince: resourceModified
        )
        #expect(Conditional.evaluate(req, against: resource) == .notModified)
    }

    @Test("If-Modified-Since on PUT is ignored")
    func ifModifiedSinceNonReadOnly() {
        let req = Conditional.Request(
            method: "PUT",
            ifModifiedSince: EvaluatorSuite.gmt(2024, 6, 1, 0, 0, 0)
        )
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }

    @Test("If-None-Match present suppresses If-Modified-Since")
    func ifNoneMatchSuppressesIMS() {
        // Even though IMS would say 304, an If-None-Match miss → proceed.
        let req = Conditional.Request(
            method: "GET",
            ifNoneMatch: .list([Conditional.ETag(value: "other")]),
            ifModifiedSince: EvaluatorSuite.gmt(2024, 6, 1, 0, 0, 0)
        )
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }

    // --- Empty resource paths ---

    @Test("If-None-Match list against ETag-less resource → proceed")
    func ifNoneMatchNoETag() {
        let req = Conditional.Request(
            method: "GET",
            ifNoneMatch: .list([Conditional.ETag(value: "v1")])
        )
        let etagless = Conditional.Resource(etag: nil, lastModified: resourceModified, exists: true)
        #expect(Conditional.evaluate(req, against: etagless) == .proceed)
    }

    @Test("No conditional headers → proceed")
    func noHeaders() {
        let req = Conditional.Request(method: "GET")
        #expect(Conditional.evaluate(req, against: resource) == .proceed)
    }
}
