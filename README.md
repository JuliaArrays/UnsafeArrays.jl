# UnsafeArrays.jl

[![Build Status](https://travis-ci.org/oschulz/UnsafeArrays.jl.svg?branch=master)](https://travis-ci.org/oschulz/UnsafeArrays.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/github/oschulz/UnsafeArrays.jl?branch=master&svg=true)](https://ci.appveyor.com/project/oschulz/unsafearrays-jl/branch/master)
[![codecov](https://codecov.io/gh/oschulz/UnsafeArrays.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/oschulz/UnsafeArrays.jl)

UnsafeArrays provides stack-allocated pointer-based array views for Julia.
This package is mainly intended as a workaround for
[Julia issue #14955 (non-allocating array views)](https://github.com/JuliaLang/julia/issues/14955).

While the Julia compiler is able to elide heap-allocation of views in some
cases, it cannot always do so. In some other cases, the relative cost of
allocation and garbage collection of a even a large number of views is small.
Especially in multi-threaded applications though, this cost can quickly become
prohibitive and views must either be avoided (resulting in more lengthy and
less readable code), or some form stack-allocated views must be used for
decent scalability. UnsafeArrays aims to provide such a solution.

Example:

```
using Compat, Base.Threads, Compat.LinearAlgebra
using Compat: axes

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

```
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
