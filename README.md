# UnsafeArrays.jl

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![Build Status](https://github.com/JuliaArrays/UnsafeArrays.jl/workflows/CI/badge.svg?branch=main)](https://github.com/JuliaArrays/UnsafeArrays.jl/actions?query=workflow%3ACI)
[![Codecov](https://codecov.io/gh/JuliaArrays/UnsafeArrays.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaArrays/UnsafeArrays.jl)

UnsafeArrays provides stack-allocated pointer-based array views for Julia.

This package is mainly intended as a workaround for
[Julia issue #14955 (non-allocating array views)](https://github.com/JuliaLang/julia/issues/14955). This issue is solved in Julia v1.5 and higher.

In Julia versions 1.4 and below, the Julia compiler is sometimes able to
elide heap-allocation of views in some, but cannot always do so. If the view
can't be elided, the relative cost of allocation and garbage collection of a
views is usually still small, in single-threaded applications. But in
in multi-threaded applications that use a large number of views, this cost can
quickly become prohibitive and views must either be avoided (resulting in more
lengthy and less readable code), or some form stack-allocated views must be
used for decent scalability. UnsafeArrays provides such a solution.
With Julia v1.5 and higher, using UnsafeArrays should not be necessary and is
not likely to result in significant performance gains.

Starting with v1.5, Julia can allocate immutable objects that contain
heap references on the stack, making UnsafeArrays.jl largely unnecessary.
It may still be useful as a lightweight wrapper for memory allocated outside
of Julia's memory management.

Example:

```julia
using Base.Threads, LinearAlgebra

function colnorms!(dest::AbstractVector, A::AbstractMatrix)
    @threads for i in axes(A, 2)
        dest[i] = norm(view(A, :, i))
    end
    dest
end

A = rand(50, 100000);
dest = similar(A, size(A, 2));

colnorms!(dest, A)
```

The above will run fine on a single thread, but scales badly on multiple
threads. Use the `@uviews` macro provided by UnsafeArrays to replace A with an
`UnsafeArray` within the scope of the macro. An `UnsafeArray` is
stack-allocated, and so are all views of it, e.g. within `colnorms!`:

```julia
using UnsafeArrays

@uviews A begin
    colnorms!(dest, A)
end
```

`@uviews` protects the original array `A` from GC, so the above is safe as
long as the original array is not reallocated (via `resize!`, etc.) while the
scope of `@uviews` is active.

UnsafeArrays only supports bits types. If the element type of an array is not
compatible, @uviews will simply use the original array.

UnsafeArrays also provides:

* A non macro-variant `uviews()`

* A function `uview()` to directly get an unsafe view (with optional
  sub-indexing) of an array.

* The type `UnsafeArray` itself, instances can be constructed from a data
  pointer and array size. The data type must be a bits type.

When using `uview()` and `UnsafeArray` directly, the user is responsible for
preserving the memory accessed from garbage collection.
