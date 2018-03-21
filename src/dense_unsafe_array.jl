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

    DenseUnsafeArray{T}(pointer::Ptr{T}, size::NTuple{N,Int})

Note: It's safe to construct an empty multidimensional `DenseUnsafeArray`:

    DenseUnsafeArray(Ptr{Int}(0), (0,...))

Usage as a view:

    U = view(DenseUnsafeArray, A::DenseArray, Colon()..., inds::Integer...)

`A` must be an non-strided, column-major array with one-based indexing. `inds`
must select a contiguous region in memory: `view(DenseUnsafeArray, A, :, 2:4, 7)`
is valid, but `view(DenseUnsafeArray, A, :, 7, 2:4)` is not.

Note: You *must* ensure that `A` is not garbage collected or reallocated
via (e.g.) `resize!`, `sizehint!` etc. while `U` is in use! Use only in
situations where you have full control over the life cycle of `A` and `U`.
"""
struct DenseUnsafeArray{T,N} <: DenseArray{T,N}
    pointer::Ptr{T}
    size::NTuple{N,Int}

    function DenseUnsafeArray{T,N}(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N}
        if isbits(T)
            new{T,N}(pointer, size)
        else
            throw(ArgumentError("Intended element type $T of DenseUnsafeArray is not a bitstype"))
        end
    end
end

DenseUnsafeArray(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} = DenseUnsafeArray{T,N}(pointer, size)

export DenseUnsafeArray


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


Base.@propagate_inbounds Base.view(A::DenseUnsafeArray, I...) =
    Base.unsafe_view(A, Base.to_indices(A, I)...)


@inline function Base.unsafe_view(A::DenseUnsafeArray{T,N}, I::Vararg{DenseIdx,N}) where {T,N}
    @boundscheck checkbounds(A, I...)
    s = size(A)
    IA = axes(A)
    p = pointer(A, _fast_sub2ind(s, _sub_startidxs(IA, I...)...))
    sub_s = _sub_size(I...)
    DenseUnsafeArray(p, sub_s)
end

@inline function Base.unsafe_view(A::DenseUnsafeArray{T,N}, i::DenseIdx) where {T,N}
    @boundscheck checkbounds(A, i)
    p = pointer(A, first(i))
    sub_s = (length(i),)
    DenseUnsafeArray(p, sub_s)
end


@inline Base.reshape(A::DenseUnsafeArray, dims::Dims) =
    DenseUnsafeArray(A.pointer, dims)


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

Base.@propagate_inbounds function _maybe_unsafe_uview(::Val{true}, A::DenseArray{T,N}) where {T,N}
    @boundscheck _require_one_based_indexing(A)
    DenseUnsafeArray(pointer(A), size(A))
end

Base.@propagate_inbounds _maybe_unsafe_uview(::Val{false}, A::DenseArray{T,N}) where {T,N} = A
