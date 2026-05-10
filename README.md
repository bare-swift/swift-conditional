# swift-conditional

RFC 7232 conditional-request primitives — `ETag`, `If-Match`, `If-None-Match`, `If-Modified-Since`, `If-Unmodified-Since`, `Last-Modified` — plus a precondition evaluator implementing the § 6 ladder. Sendable, Foundation-free, typed throws.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-conditional.git", from: "0.1.0")
```

Then depend on the `Conditional` product:

```swift
.product(name: "Conditional", package: "swift-conditional")
```

## Usage

```swift
import Conditional
import Time

// Parse incoming request headers.
let ifNoneMatch = try Conditional.parseETagList("\"v1\", W/\"v2\"")
let ifModifiedSince = try Conditional.parseHTTPDate("Sun, 06 Nov 1994 08:49:37 GMT")

let request = Conditional.Request(
    method: "GET",
    ifNoneMatch: ifNoneMatch,
    ifModifiedSince: ifModifiedSince
)

// Snapshot of the resource you'd be returning.
let resource = Conditional.Resource(
    etag: Conditional.ETag(value: "v1"),
    lastModified: Calendar(year: 1994, month: 11, day: 6,
                          hour: 8, minute: 49, second: 37,
                          nanosecond: 0, offsetSeconds: 0)
)

switch Conditional.evaluate(request, against: resource) {
case .proceed:           respondWith200()
case .notModified:       respondWith304()
case .preconditionFailed: respondWith412()
}
```

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-conditional/>

## Source

Native bare-swift package. RFC 7232 / RFC 7231 § 7.1.1.1 reference implementation; no upstream Rust crate.

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
