// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// RFC 7232 conditional-request primitives — `ETag`, `If-Match`,
/// `If-None-Match`, `If-Modified-Since`, `If-Unmodified-Since`,
/// `Last-Modified` — plus a precondition evaluator implementing the
/// § 6 ladder.
///
/// Foundation-free, Sendable, typed throws.
public enum Conditional {}
