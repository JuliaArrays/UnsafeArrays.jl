# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

using Base: @propagate_inbounds
using Base.MultiplicativeInverses: SignedMultiplicativeInverse


"""
    UnsafeArray{T,N} <: DenseArray{T,N}

An `UnsafeArray` is an bitstype wrapper around a memory pointer and a
size tuple. It's an intended to be used as a short-lived, allocation-free
alternative to an an `Array` returned by `unsafe_wrap` or a `SubArray`
returned by `view` or . Use with caution!

Constructors:

    UnsafeArray{T,N}(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N}
    UnsafeArray(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N}

UnsafeArray requires `isbits(T) == true`.

Note: It's safe to construct an empty multidimensional `UnsafeArray`:

    UnsafeArray(Ptr{Int}(0), (0,...))

Note: You *must* ensure that `A` is not garbage collected or reallocated
via (e.g.) `resize!`, `sizehint!` etc. while `U` is in use! Use only in
situations where you have full control over the life cycle of `A` and `U`.
"""
struct UnsafeArray{T,N} <: DenseArray{T,N}
    pointer::Ptr{T}
    size::NTuple{N,Int}

    UnsafeArray{T,N}(isbits_T::Val{true}, pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
        new{T,N}(pointer, size)
end

export UnsafeArray

UnsafeArray{T,N}(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
    UnsafeArray{T,N}(Val{isbits(T)}(), pointer, size)

UnsafeArray(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
    UnsafeArray{T,N}(pointer, size)


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

Base.unsafe_convert(::Type{Ptr{T}}, A::UnsafeArray{T}) where T = A.pointer

Base.iscontiguous(::UnsafeArray) = true


Base.@propagate_inbounds Base.view(A::UnsafeArray) = Base.unsafe_view(A)

Base.@propagate_inbounds function Base.view(A::UnsafeArray, idx, I...)
    J = Base.to_indices(A, (idx, I...))
    @boundscheck checkbounds(A, J...)
    Base.unsafe_view(A, J...)
end


Base.@propagate_inbounds Base.unsafe_view(A::UnsafeArray{T,N}, I::Vararg{Base.ViewIndex,N}) where {T,N} =
    _unsafe_view_impl((), A, I...)

Base.@propagate_inbounds Base.unsafe_view(A::UnsafeArray{T,N}, i::Base.ViewIndex) where {T,N} =
    _unsafe_view_impl((), A, i)


@inline function _unsafe_view_impl(IFwd::NTuple{N,Base.Slice}, A::UnsafeArray{T,N}) where {T,N}
    @assert IFwd == axes(A)
    A
end

Base.@propagate_inbounds _unsafe_view_impl(IFwd::NTuple{N,Base.ViewIndex}, A::UnsafeArray{T,N}) where {T,N} =
    SubArray(A, IFwd)

Base.@propagate_inbounds _unsafe_view_impl(IFwd::NTuple{M,Base.ViewIndex}, A::UnsafeArray{T,N}, i::Base.ViewIndex, I::Base.ViewIndex...) where {T,M,N} =
    _unsafe_view_impl((IFwd..., i), A, I...)

@inline function _unsafe_view_impl(IFwd::NTuple{M,Base.Slice}, A::UnsafeArray{T,N}, i::DenseIdx, I::Integer...) where {T,M,N}
    @assert IFwd == ntuple(i -> axes(A)[i], Val{M}())
    I_all = (IFwd..., i, I...)
    @boundscheck checkbounds(A, I_all...)
    startidxs = map(first, (IFwd..., i, I...))
    sub_s = _sub_size(I_all...)
    p = pointer(A, _fast_sub2ind(size(A), startidxs...))
    UnsafeArray(p, sub_s)
end

@inline function _unsafe_view_impl(IFwd::Tuple{}, A::UnsafeArray{T,N}, i::DenseIdx) where {T,N}
    @boundscheck checkbounds(A, i)
    p = pointer(A, first(i))
    sub_s = (length(i),)
    UnsafeArray(p, sub_s)
end



@inline Base.__reshape(p::Tuple{UnsafeArray,IndexLinear}, dims::Dims) =
    UnsafeArray(p[1].pointer, dims)


# From Julia Base (same implementation, with slight variations):

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
        ccall(:jl_array_ptr_copy, Cvoid, (Any, Ptr{Cvoid}, Any, Ptr{Cvoid}, Int),
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
        ccall(:jl_array_ptr_copy, Cvoid, (Any, Ptr{Cvoid}, Any, Ptr{Cvoid}, Int),
              dest, pointer(dest, doffs), src, pointer(src, soffs), n)
    end
    return dest
end
