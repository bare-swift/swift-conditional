# ``Conditional``

RFC 7232 conditional-request primitives — Sendable, Foundation-free.

## Overview

`Conditional` implements ETag and HTTP-date header parsing plus a full
RFC 7232 § 6 precondition ladder — enough for a server to evaluate
`If-Match`, `If-None-Match`, `If-Modified-Since`, `If-Unmodified-Since`
against a snapshot of the targeted resource and decide between
`200/206`, `304 Not Modified`, and `412 Precondition Failed`.

```swift
import Conditional

let request = Conditional.Request(
    method: "GET",
    ifNoneMatch: try Conditional.parseETagList("\"v1\", W/\"v2\"")
)
let resource = Conditional.Resource(etag: Conditional.ETag(value: "v1"))

switch Conditional.evaluate(request, against: resource) {
case .notModified: break        // 304
case .preconditionFailed: break // 412
case .proceed: break            // continue normal handling
}
```

HTTP-date headers are parsed via swift-time's RFC 1123 codec, returning
`Calendar` values that can be compared at one-second resolution.
RFC 850 and `asctime()` legacy formats are intentionally out of scope —
real-world traffic uses IMF-fixdate.

## Topics

### Entity tags

- ``Conditional/ETag``
- ``Conditional/parseETag(_:)``

### ETag lists (`If-Match` / `If-None-Match`)

- ``Conditional/ETagList``
- ``Conditional/parseETagList(_:)``
- ``Conditional/serializeETagList(_:)``

### HTTP-date headers

- ``Conditional/parseHTTPDate(_:)``
- ``Conditional/serializeHTTPDate(_:)``

### Precondition evaluator

- ``Conditional/Request``
- ``Conditional/Resource``
- ``Conditional/Outcome``
- ``Conditional/evaluate(_:against:)``

### Errors

- ``ConditionalError``
