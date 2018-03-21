# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

const UnsafeArray{T,N} = Union{DenseUnsafeArray{T,N}}

export UnsafeArray


@doc doc"""
    uview(A::AbstractArray, I...)

Unsafe equivalent of `view`. May return an `UnsafeArray`, a standard
`SubArray` or `A` itself, depending on `I...` and the type of `A`.

As `uview` may return an `UnsafeArray`, `A` itself *must* be protected from
garbage collection while the view of `A` is in use.

To provide support for `uview` for custom array types, add methods to
function `UnsafeArrays.unsafe_uview`.
"""
function uview end
export uview

Base.@propagate_inbounds uview(A::AbstractArray{T}, I...) where {T} =
    _maybe_uview(Val{isbits(T)}(), A, I...)

Base.@propagate_inbounds uview(A::UnsafeArray) = A


Base.@propagate_inbounds _maybe_uview(::Val{false}, A::AbstractArray{T,N}, I::Vararg{Any,N}) where {T,N} = view(A, I...)
Base.@propagate_inbounds _maybe_uview(::Val{false}, A::AbstractArray{T,N}, i::Any) where {T,N} = view(A, i)
Base.@propagate_inbounds _maybe_uview(::Val{false}, A::AbstractArray{T,N}) where {T,N} = A

Base.@propagate_inbounds function _maybe_uview(::Val{true}, A::AbstractArray, I...)
    J = Base.to_indices(A, I)
    unsafe_uview(A, J...)
end


@doc doc"""
    UnsafeArray.unsafe_uview(A::AbstractArray, I::Vararg{Base.ViewIndex,N})
    UnsafeArray.unsafe_uview(A::AbstractArray, i::Base.ViewIndex)
    UnsafeArray.unsafe_uview(A::AbstractArray)

To support `uview` for custom array types, add methods to `unsafe_uview`
instead of `uview`.

Implementing `UnsafeArray.unsafe_uview(A::CustomArrayType)` will often
be sufficient if specialized methods of `Base.unsafe_view` are provided
for `CustomArrayType`.
"""
function unsafe_uview end

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}, I::Vararg{Base.ViewIndex,N}) where {T,N} =
    Base.unsafe_view(unsafe_uview(A), I...)

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}, i) where {T,N} =
    Base.unsafe_view(unsafe_uview(A), i::Base.ViewIndex)

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}) where {T,N} = A

Base.@propagate_inbounds unsafe_uview(A::UnsafeArray{T,N}) where {T,N} = A


@doc doc"""
    @uview A[inds...]

Unsafe equivalent of `@view`. Uses `uview` instead of `view`.
"""
macro uview(ex)
    # From Julia Base (same implementation, but using uview):

    if Meta.isexpr(ex, :ref)
        ex = Base.replace_ref_end!(ex)
        if Meta.isexpr(ex, :ref)
            ex = Expr(:call, view, DenseUnsafeArray, ex.args...)
        else # ex replaced by let ...; foo[...]; end
            assert(Meta.isexpr(ex, :let) && Meta.isexpr(ex.args[2], :ref))
            ex.args[2] = Expr(:call, uview, ex.args[2].args...)
        end
        Expr(:&&, true, esc(ex))
    else
        throw(ArgumentError("Invalid use of @view macro: argument must be a reference expression A[...]."))
    end
end

export @uview
