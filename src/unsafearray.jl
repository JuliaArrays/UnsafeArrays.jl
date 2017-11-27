# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

using Base: @propagate_inbounds
using Base.MultiplicativeInverses: SignedMultiplicativeInverse


doc"""
    UnsafeArray{T,N} <: DenseArray{T,N}

An `UnsafeArray` is an bitstype wrapper around a memory pointer and a
size tuple. It's an intended to be used as a short-lived, allocation-free
alternative to an an `Array` returned by `unsafe_wrap` or a `SubArray`
returned by `view` or . Use with caution!

Constructors:

    UnsafeArray{T}(pointer::Ptr{T}, size::NTuple{N,Int})

Note: It's safe to construct an empty multidimensional `UnsafeArray`:

    UnsafeArray(Ptr{Int}(0), (0,...))

Usage as a view:

    U = view(UnsafeArray, A::DenseArray, Colon()..., inds::Integer...)

`A` must be an non-strided, column-major array with one-based indices. `inds`
must select a contiguous region in memory: `view(UnsafeArray, A, :, 2:4, 7)`
is valid, but `view(UnsafeArray, A, :, 7, 2:4)` is not.

Note: You *must* ensure that `A` is not garbage collected or reallocated
via (e.g.) `resize!`, `sizehint!` etc. while `U` is in use! Use only in
situations where you have full control over the life cycle of `A` and `U`.
"""
struct UnsafeArray{T,N} <: DenseArray{T,N}
    pointer::Ptr{T}
    size::NTuple{N,Int}

    function UnsafeArray{T,N}(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N}
        if isbits(T)
            new{T,N}(pointer, size)
        else
            throw(ArgumentError("Intended element type $T of UnsafeArray is not a bitstype"))
        end
    end
end

UnsafeArray(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} = UnsafeArray{T,N}(pointer, size)

export UnsafeArray


Base.size(A::UnsafeArray) = A.size

@inline function Base.getindex(A::UnsafeArray, i::Integer)
    @boundscheck checkbounds(A, i)
    unsafe_load(A.pointer, i)
end

@inline function Base.setindex!(A::UnsafeArray, x, i::Integer)
    @boundscheck checkbounds(A, i)
    unsafe_store!(A.pointer, x, i)
end

@inline Base.IndexStyle(A::UnsafeArray) = IndexLinear()

Base.length(A::UnsafeArray{T,0}) where {T} = 0
Base._length(A::UnsafeArray{T,0}) where {T} = 0

Base.unsafe_convert(::Type{Ptr{T}}, A::UnsafeArray{T}) where T = A.pointer


@inline function Base.view(UnsafeArray, A::DenseArray{T,N}, inds::Vararg{SubIdx,N}) where {T,N}
    @boundscheck begin
        checkbounds(A, inds...)
        typeof(indices(A)) == NTuple{N,Base.OneTo{Int}} || throw(ArgumentError("Parent array must have one-based indexing"))
    end
    s = size(A)
    p = pointer(A, sub2ind(s, _sub_startidx(inds...)...))
    sub_s = _sub_size(size(A), inds...)
    UnsafeArray(p, sub_s)
end


# From Julia Base:

Base.copy!(dest::Array{T}, src::UnsafeArray{T}) where {T} = copy!(dest, 1, src, 1, length(src))

function Base.copy!(dest::Array{T}, doffs::Integer, src::UnsafeArray{T}, soffs::Integer, n::Integer) where {T}
    n == 0 && return dest
    n > 0 || throw(ArgumentError(string("tried to copy n=", n, " elements, but n should be nonnegative")))
    if soffs < 1 || doffs < 1 || soffs+n-1 > length(src) || doffs+n-1 > length(dest)
        throw(BoundsError())
    end
    unsafe_copy!(dest, doffs, src, soffs, n)
end

function Base.unsafe_copy!(dest::Array{T}, doffs::Integer, src::UnsafeArray{T}, soffs::Integer, n::Integer) where {T}
    if isbits(T)
        unsafe_copy!(pointer(dest, doffs), pointer(src, soffs), n)
    else
        ccall(:jl_array_ptr_copy, Void, (Any, Ptr{Void}, Any, Ptr{Void}, Int),
              dest, pointer(dest, doffs), src, pointer(src, soffs), n)
    end
    return dest
end

Base.copy!(dest::UnsafeArray{T}, src::Array{T}) where {T} = copy!(dest, 1, src, 1, length(src))

function Base.copy!(dest::UnsafeArray{T}, doffs::Integer, src::Array{T}, soffs::Integer, n::Integer) where {T}
    n == 0 && return dest
    n > 0 || throw(ArgumentError(string("tried to copy n=", n, " elements, but n should be nonnegative")))
    if soffs < 1 || doffs < 1 || soffs+n-1 > length(src) || doffs+n-1 > length(dest)
        throw(BoundsError())
    end
    unsafe_copy!(dest, doffs, src, soffs, n)
end

function Base.unsafe_copy!(dest::UnsafeArray{T}, doffs::Integer, src::Array{T}, soffs::Integer, n::Integer) where {T}
    if isbits(T)
        unsafe_copy!(pointer(dest, doffs), pointer(src, soffs), n)
    else
        ccall(:jl_array_ptr_copy, Void, (Any, Ptr{Void}, Any, Ptr{Void}, Int),
              dest, pointer(dest, doffs), src, pointer(src, soffs), n)
    end
    return dest
end
