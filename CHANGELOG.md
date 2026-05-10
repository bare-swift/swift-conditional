# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-05-10

### Added
- `Conditional.ETag` value type with `value: String` + `isWeak: Bool`, `serialized()`, `strongMatches(_:)` and `weakMatches(_:)` per RFC 7232 § 2.3.2.
- `Conditional.parseETag(_:) throws(ConditionalError) -> ETag` — accepts `"opaque"` and `W/"opaque"`; tolerates surrounding whitespace; collapses backslash-escapes.
- `Conditional.ETagList` enum (`.any` for `*`, `.list([ETag])`) plus `parseETagList(_:)` and `serializeETagList(_:)` for `If-Match:` / `If-None-Match:`.
- `Conditional.parseHTTPDate(_:) throws(ConditionalError) -> Time.Calendar` and `Conditional.serializeHTTPDate(_:) -> String` for `If-Modified-Since:`, `If-Unmodified-Since:`, `Last-Modified:` (RFC 1123 IMF-fixdate, via swift-time).
- `Conditional.Request` and `Conditional.Resource` snapshot types and `Conditional.Outcome` (`.proceed` / `.notModified` / `.preconditionFailed`).
- `Conditional.evaluate(_:against:) -> Outcome` implementing the RFC 7232 § 6 precondition ladder for steps 1–4 (Range — step 5 — is delegated to swift-range).
- `ConditionalError` typed-throws enum (`malformedHeader`, `malformedETag`, `malformedDate`).
- 39 tests across 4 suites covering: ETag parse / weak vs. strong comparison / round-trip; ETag-list parse with whitespace, mixed strength, wildcard, error paths; RFC 1123 date round-trip and rejection; full evaluator ladder including step suppression rules, weak/strong comparison, wildcard against missing-vs-present resources, and read-only-method gating.

### Dependencies
- `swift-time` 0.1.0 — `Calendar` and RFC 1123 parser.

### Limitations (out of scope for v0.1)
- `If-Range` (RFC 7233 § 3.2). Lives at the swift-conditional × swift-range intersection — will land as a v0.2 method on `Conditional` once the integration shape is settled.
- Legacy date formats: RFC 850 obsolete syntax and `asctime()` are not parsed; only RFC 1123 IMF-fixdate is supported. Real-world traffic almost exclusively uses the preferred form.
- `Vary:` semantics. Vary is content-negotiation, not precondition machinery.
- `Codable` bridging — same Foundation-free / non-Codable differentiator as the rest of the format tier.
