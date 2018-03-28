# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

using Base: @propagate_inbounds
using Base.MultiplicativeInverses: SignedMultiplicativeInverse


@doc doc"""
    DenseUnsafeArray{T,N} <: DenseArray{T,N}

An `DenseUnsafeArray` is an bitstype wrapper around a memory pointer and a
size tuple. It's an intended to be used as a short-lived, allocation-free
alternative to an an `Array` returned by `unsafe_wrap` or a `SubArray`
returned by `view` or . Use with caution!

Constructors:

    DenseUnsafeArray{T,N}(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N}
    DenseUnsafeArray(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N}

DenseUnsafeArray requires `isbits(T) == true`.

Note: It's safe to construct an empty multidimensional `DenseUnsafeArray`:

    DenseUnsafeArray(Ptr{Int}(0), (0,...))

Note: You *must* ensure that `A` is not garbage collected or reallocated
via (e.g.) `resize!`, `sizehint!` etc. while `U` is in use! Use only in
situations where you have full control over the life cycle of `A` and `U`.
"""
struct DenseUnsafeArray{T,N} <: DenseArray{T,N}
    pointer::Ptr{T}
    size::NTuple{N,Int}

    DenseUnsafeArray{T,N}(isbits_T::Val{true}, pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
        new{T,N}(pointer, size)
end

export DenseUnsafeArray

DenseUnsafeArray{T,N}(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
    DenseUnsafeArray{T,N}(Val{isbits(T)}(), pointer, size)

DenseUnsafeArray(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
    DenseUnsafeArray{T,N}(pointer, size)


Base.size(A::DenseUnsafeArray) = A.size

@inline function Base.getindex(A::DenseUnsafeArray, i::Integer)
    @boundscheck checkbounds(A, i)
    unsafe_load(A.pointer, i)
end

@inline function Base.setindex!(A::DenseUnsafeArray, x, i::Integer)
    @boundscheck checkbounds(A, i)
    unsafe_store!(A.pointer, x, i)
end

@inline Base.IndexStyle(A::DenseUnsafeArray) = IndexLinear()

Base.length(A::DenseUnsafeArray{T,0}) where {T} = 0
Base._length(A::DenseUnsafeArray{T,0}) where {T} = 0

Base.unsafe_convert(::Type{Ptr{T}}, A::DenseUnsafeArray{T}) where T = A.pointer

Base.iscontiguous(::DenseUnsafeArray) = true


Base.@propagate_inbounds function Base.view(A::DenseUnsafeArray, I...)
    J = Base.to_indices(A, I)
    @boundscheck checkbounds(A, J...)
    Base.unsafe_view(A, J...)
end


Base.@propagate_inbounds Base.unsafe_view(A::DenseUnsafeArray{T,N}, I::Vararg{Base.ViewIndex,N}) where {T,N} =
    _unsafe_view_impl((), A, I...)

Base.@propagate_inbounds Base.unsafe_view(A::DenseUnsafeArray{T,N}, i::Base.ViewIndex) where {T,N} =
    _unsafe_view_impl((), A, i)


@inline function _unsafe_view_impl(IFwd::NTuple{N,Base.Slice}, A::DenseUnsafeArray{T,N}) where {T,N}
    @assert IFwd == axes(A)
    A
end

Base.@propagate_inbounds _unsafe_view_impl(IFwd::NTuple{N,Base.ViewIndex}, A::DenseUnsafeArray{T,N}) where {T,N} =
    SubArray(A, IFwd)

Base.@propagate_inbounds _unsafe_view_impl(IFwd::NTuple{M,Base.ViewIndex}, A::DenseUnsafeArray{T,N}, i::Base.ViewIndex, I::Base.ViewIndex...) where {T,M,N} =
    _unsafe_view_impl((IFwd..., i), A, I...)

@inline function _unsafe_view_impl(IFwd::NTuple{M,Base.Slice}, A::DenseUnsafeArray{T,N}, i::DenseIdx, I::Integer...) where {T,M,N}
    @assert IFwd == ntuple(i -> axes(A)[i], Val{M}())
    I_all = (IFwd..., i, I...)
    @boundscheck checkbounds(A, I_all...)
    startidxs = map(first, (IFwd..., i, I...))
    sub_s = _sub_size(I_all...)
    p = pointer(A, _fast_sub2ind(size(A), startidxs...))
    DenseUnsafeArray(p, sub_s)
end

@inline function _unsafe_view_impl(IFwd::Tuple{}, A::DenseUnsafeArray{T,N}, i::DenseIdx) where {T,N}
    @boundscheck checkbounds(A, i)
    p = pointer(A, first(i))
    sub_s = (length(i),)
    DenseUnsafeArray(p, sub_s)
end



@inline Base.__reshape(p::Tuple{DenseUnsafeArray,IndexLinear}, dims::Dims) =
    DenseUnsafeArray(p[1].pointer, dims)


# From Julia Base (same implementation, with slight variations):

Base.copy!(dest::Array{T}, src::DenseUnsafeArray{T}) where {T} = copy!(dest, 1, src, 1, length(src))

function Base.copy!(dest::Array{T}, doffs::Integer, src::DenseUnsafeArray{T}, soffs::Integer, n::Integer) where {T}
    n == 0 && return dest
    n > 0 || throw(ArgumentError(string("tried to copy n=", n, " elements, but n should be nonnegative")))
    if soffs < 1 || doffs < 1 || soffs+n-1 > length(src) || doffs+n-1 > length(dest)
        throw(BoundsError())
    end
    unsafe_copy!(dest, doffs, src, soffs, n)
end

function Base.unsafe_copy!(dest::Array{T}, doffs::Integer, src::DenseUnsafeArray{T}, soffs::Integer, n::Integer) where {T}
    if isbits(T)
        unsafe_copy!(pointer(dest, doffs), pointer(src, soffs), n)
    else
        ccall(:jl_array_ptr_copy, Cvoid, (Any, Ptr{Cvoid}, Any, Ptr{Cvoid}, Int),
              dest, pointer(dest, doffs), src, pointer(src, soffs), n)
    end
    return dest
end

Base.copy!(dest::DenseUnsafeArray{T}, src::Array{T}) where {T} = copy!(dest, 1, src, 1, length(src))

function Base.copy!(dest::DenseUnsafeArray{T}, doffs::Integer, src::Array{T}, soffs::Integer, n::Integer) where {T}
    n == 0 && return dest
    n > 0 || throw(ArgumentError(string("tried to copy n=", n, " elements, but n should be nonnegative")))
    if soffs < 1 || doffs < 1 || soffs+n-1 > length(src) || doffs+n-1 > length(dest)
        throw(BoundsError())
    end
    unsafe_copy!(dest, doffs, src, soffs, n)
end

function Base.unsafe_copy!(dest::DenseUnsafeArray{T}, doffs::Integer, src::Array{T}, soffs::Integer, n::Integer) where {T}
    if isbits(T)
        unsafe_copy!(pointer(dest, doffs), pointer(src, soffs), n)
    else
        ccall(:jl_array_ptr_copy, Cvoid, (Any, Ptr{Cvoid}, Any, Ptr{Cvoid}, Int),
              dest, pointer(dest, doffs), src, pointer(src, soffs), n)
    end
    return dest
end



Base.@propagate_inbounds unsafe_uview(A::DenseArray{T,N}) where {T,N} =
    _maybe_unsafe_uview(Val{isbits(T)}(), A)

Base.@propagate_inbounds function _maybe_unsafe_uview(isbits_T::Val{true}, A::DenseArray{T,N}) where {T,N}
    @boundscheck _require_one_based_indexing(A)
    DenseUnsafeArray{T,N}(isbits_T, pointer(A), size(A))
end

Base.@propagate_inbounds _maybe_unsafe_uview(isbits_T::Val{false}, A::DenseArray{T,N}) where {T,N} = A
