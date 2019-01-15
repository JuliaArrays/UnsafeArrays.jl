# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).


"""
    uview(A::AbstractArray, I...)

Unsafe equivalent of `view`. May return an `UnsafeArray`, a standard
`SubArray` or `A` itself, depending on `I...` and the type of `A`.

As `uview` may return an `UnsafeArray`, `A` itself and it's contents *must* be
protected from garbage collection (e.g. via `GC.@preserve` on Julia > v0.6)
and memory reallocation while the view is in use.

Use `uviews(f::Function, As::AbstractArray...)` or `@uviews A ... expr` to
use unsafe views of one or multiple arrays with automatically GC protection.

```
uviews(A, B, ...) do (A_u, B_u, ...)
    # Do something with the unsafe views A_u, B_u, ...
    # Code here must not resize/append/etc. A, B, ...
end
```

To provide support for `uview` for custom array types, add methods to
function `UnsafeArrays.unsafe_uview`.
"""
function uview end
export uview

Base.@propagate_inbounds uview(A::AbstractArray) = unsafe_uview(A)

Base.@propagate_inbounds function uview(A::AbstractArray, idx, I...)
    J = Base.to_indices(A, (idx, I...))
    @boundscheck checkbounds(A, J...)
    unsafe_uview(A, J...)
end


Base.@propagate_inbounds uview(A::UnsafeArray) = A


"""
    UnsafeArray.unsafe_uview(A::AbstractArray, I::Vararg{Base.ViewIndex,N})
    UnsafeArray.unsafe_uview(A::AbstractArray, i::Base.ViewIndex)
    UnsafeArray.unsafe_uview(A::AbstractArray)

To support `uview` for custom array types, add methods to `unsafe_uview`
instead of `uview`. Implementing
`UnsafeArray.unsafe_uview(A::CustomArrayType)` will often be sufficient.

It may be necessary to provide a custom implementation of `Base.deepcopy`
for types with a custom implementation of `unsafe_uview`, to ensure that
the result of `deepcopy` does *NOT* contain unsafe views.
"""
function unsafe_uview end

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}, I::Vararg{Base.ViewIndex,N}) where {T,N} =
    Base.unsafe_view(unsafe_uview(A), I...)

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}, i) where {T,N} =
    Base.unsafe_view(unsafe_uview(A), i::Base.ViewIndex)

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}) where {T,N} = A

Base.@propagate_inbounds unsafe_uview(A::UnsafeArray{T,N}) where {T,N} = A


Base.@propagate_inbounds unsafe_uview(A::DenseArray{T,N}) where {T,N} =
    _maybe_unsafe_uview(Val{isbitstype(T)}(), A)

Base.@propagate_inbounds unsafe_uview(A::SubArray{T,N}) where {T,N} =
    _maybe_unsafe_uview(Val{isbitstype(T) && Base.iscontiguous(typeof(A))}(), A)

Base.@propagate_inbounds function _maybe_unsafe_uview(unsafe_compatible::Val{true}, A::AbstractArray{T,N}) where {T,N}
    @boundscheck _require_one_based_indexing(A)
    UnsafeArray{T,N}(unsafe_compatible, pointer(A), size(A))
end

Base.@propagate_inbounds _maybe_unsafe_uview(unsafe_compatible::Val{false}, A::AbstractArray{T,N}) where {T,N} = A


"""
    uviews(f::Function, As::AbstractArray...)

Equivalent to `f(map(uview, As)...)`. Automatically protects the array(s)
`As` from garbage collection during execution of `f`.

Example:

```
uviews(A, B, ...) do (A_u, B_u, ...)
    # Do something with the unsafe views A_u, B_u, ...
    # Code here must not resize/append/etc. A, B, ...
end
```

In many cases, it may be preferable to use `@uviews` insted of `views`.
"""
function uviews end
export uviews

@inline function uviews(f::Function, As::AbstractArray...)
    GC.@preserve(As, f(map(uview, As)...))
end


"""
    @uviews A B ... expr

Replace arrays `A`, `B`, ... by uview(`A`), uview(`B`), ... during execution
of `expr`, while protecting the original arrays from garbage collection.

Equivalent to

```
GC.@preserve A B ... begin
    let A = uview(A), B = uview(B), ...
        expr
    end
end
```

The unsafe views must not be allowed to escape the scope of `expr`. The
original arrays must not be resized/appended/etc. during the execution of
`expr`.
"""
macro uviews(args...)
    syms = args[1:end-1]
    expr = args[end]

    binds = Expr(:block)
    for s in syms
        s isa Symbol || error("@uviews targets must be a symbols")
        push!(binds.args, :($s = UnsafeArrays.uview($s)))
    end
    let_expr = Expr(:let, binds, expr)
    esc(:(GC.@preserve $(syms...) $(let_expr)))
end

export @uviews


function Base.mightalias(A::UnsafeArray, B::UnsafeArray)
    pfA = pointer(A, firstindex(A))
    plA = pointer(A, lastindex(A))
    pfB = pointer(B, firstindex(B))
    plB = pointer(B, lastindex(B))

    (pfA <= pfB <= plA) || (pfA <= plB <= plA) || (pfB <= pfA <= plB)
end

function Base.mightalias(A::UnsafeArray, B::AbstractArray)
    @uviews B begin
        if typeof(B) <: UnsafeArray
            Base.mightalias(A, B)
        else
            false
        end
    end
end

Base.mightalias(A::AbstractArray, B::UnsafeArray) = Base.mightalias(B, A)

Base.mightalias(A::SubArray{T,N,<:UnsafeArray}, B::AbstractArray) where {T,N} =
    Base.mightalias(parent(A), B)

Base.mightalias(A::SubArray{T1,N1,<:UnsafeArray}, B::SubArray{T2,N2,<:UnsafeArray}) where {T1,N1,T2,N2} =
    Base.mightalias(parent(A), parent(B))

Base.mightalias(A::SubArray{T,N,<:UnsafeArray}, B::UnsafeArray) where {T,N} =
    Base.mightalias(parent(A), B)

Base.mightalias(A::AbstractArray, B::SubArray{T,N,<:UnsafeArray}) where {T,N} =
    Base.mightalias(B, A)

Base.mightalias(A::UnsafeArray, B::SubArray{T,N,<:UnsafeArray}) where {T,N} =
    Base.mightalias(B, A)
