# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

const UnsafeArray{T,N} = Union{DenseUnsafeArray{T,N}}

export UnsafeArray


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
uview(A, B, ...) do (A_u, B_u, ...)
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
    @static if VERSION >= v"0.7.0-DEV.3465"
        GC.@preserve(As, f(map(uview, As)...))
    else
        try
            f(map(uview, As)...)
        finally
            _noinline_nop(As)
        end
    end
end


"""
    UnsafeArray.unsafe_uview(A::AbstractArray, I::Vararg{Base.ViewIndex,N})
    UnsafeArray.unsafe_uview(A::AbstractArray, i::Base.ViewIndex)
    UnsafeArray.unsafe_uview(A::AbstractArray)

To support `uview` for custom array types, add methods to `unsafe_uview`
instead of `uview`. Implementing
`UnsafeArray.unsafe_uview(A::CustomArrayType)` will often be sufficient.
"""
function unsafe_uview end

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}, I::Vararg{Base.ViewIndex,N}) where {T,N} =
    Base.unsafe_view(unsafe_uview(A), I...)

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}, i) where {T,N} =
    Base.unsafe_view(unsafe_uview(A), i::Base.ViewIndex)

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}) where {T,N} = A

Base.@propagate_inbounds unsafe_uview(A::UnsafeArray{T,N}) where {T,N} = A


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

The unsafe views must not be allowed to escape the scope of `expr`. The
original arrays must not be resized/appended/etc. during the execution of
`expr`.
```
"""
macro uviews(args...)
    syms = args[1:end-1]
    expr = args[end]

    @static if VERSION >= v"0.7.0-DEV.3465"
        binds = Expr(:block)
        for s in syms
            s isa Symbol || error("@uviews targets must be a symbols")
            push!(binds.args, :($s = UnsafeArrays.uview($s)))
        end
        let_expr = Expr(:let, binds, expr)
        esc(:(GC.@preserve $(syms...) $(let_expr)))
    else
        let_expr = Expr(:let)
        expr isa Expr || error("Last argument of @uviews must be an expression")
        push!(let_expr.args, expr)
        for s in syms
            s isa Symbol || error("@uviews targets must be a symbols")
            push!(let_expr.args, :($s = UnsafeArrays.uview($s)))
        end

        esc(quote
            try
                $let_expr
            finally
                $(Expr(:call, :(UnsafeArrays._noinline_nop), syms))
            end
        end)
    end
end

export @uviews
