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

UnsafeArray requires `isbitstype(T) == true`.

Note: It's safe to construct an empty multidimensional `UnsafeArray`:

    UnsafeArray(Ptr{Int}(0), (0,...))

Note: You *must* ensure that `A` is not garbage collected or reallocated
via (e.g.) `resize!`, `sizehint!` etc. while `U` is in use! Use only in
situations where you have full control over the life cycle of `A` and `U`.

`deepcopy(::UnsafeArray)` returns a standard `Array`.
"""
struct UnsafeArray{T,N} <: DenseArray{T,N}
    pointer::Ptr{T}
    size::NTuple{N,Int}

    UnsafeArray{T,N}(isbits_T::Val{true}, pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
        new{T,N}(pointer, size)
end

export UnsafeArray

UnsafeArray{T,N}(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
    UnsafeArray{T,N}(Val{isbitstype(T)}(), pointer, size)

UnsafeArray(pointer::Ptr{T}, size::NTuple{N,Int}) where {T,N} =
    UnsafeArray{T,N}(pointer, size)


Base.size(A::UnsafeArray) = A.size

Base.elsize(::Type{UnsafeArray{T, N}}) where {T, N} = sizeof(T)

@inline function Base.getindex(A::UnsafeArray, i::Integer)
    @boundscheck checkbounds(A, i)
    unsafe_load(A.pointer, i)
end

@inline function Base.setindex!(A::UnsafeArray, x, i::Integer)
    @boundscheck checkbounds(A, i)
    unsafe_store!(A.pointer, x, i)
end

@inline Base.IndexStyle(A::UnsafeArray) = Base.IndexStyle(typeof(A))
Base.IndexStyle(::Type{UnsafeArray{T,N}}) where {T,N} = IndexLinear()

Base.unsafe_convert(::Type{Ptr{T}}, A::UnsafeArray{T}) where T = A.pointer

Base.iscontiguous(::UnsafeArray) = true
Base.iscontiguous(::Type{<:UnsafeArray}) = true


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
    ax_A = axes(A)
    @assert IFwd == ntuple(i -> axes(A)[i], Val{M}())
    I_all = (IFwd..., i, I...)
    @boundscheck checkbounds(A, I_all...)
    startidxs = map(first, (IFwd..., i, I...))
    firstidxs = map(first, ax_A)
    sub_s = _sub_size(I_all...)
    A_isempty = length(A) == 0
    view_isempty = prod(sub_s) == 0
    # getindex on LinearIndices fails with startidxs if A is empty, so use pseudo-size in that case:
    sz = size(A)
    pseudo_sz = ntuple(_ -> 1, Val(N))
    mod_size, mod_startidxs = ifelse(A_isempty && view_isempty, (pseudo_sz, firstidxs), (sz, startidxs))
    p = pointer(A, LinearIndices(mod_size)[mod_startidxs...])
    UnsafeArray(p, sub_s)
end

@inline function _unsafe_view_impl(IFwd::Tuple{}, A::UnsafeArray{T,N}, i::DenseIdx) where {T,N}
    @boundscheck checkbounds(A, i)
    p = pointer(A, first(i))
    sub_s = _sub_size(i)
    UnsafeArray(p, sub_s)
end



@inline Base.__reshape(p::Tuple{UnsafeArray,IndexLinear}, dims::Dims) =
    UnsafeArray(p[1].pointer, dims)


# From Julia Base (same implementation, with slight variations):

Base.copyto!(dest::Array{T}, src::UnsafeArray{T}) where {T} = copyto!(dest, 1, src, 1, length(src))

function Base.copyto!(dest::Array{T}, doffs::Integer, src::UnsafeArray{T}, soffs::Integer, n::Integer) where {T}
    n == 0 && return dest
    n > 0 || throw(ArgumentError(string("tried to copy n=", n, " elements, but n should be nonnegative")))
    if soffs < 1 || doffs < 1 || soffs+n-1 > length(src) || doffs+n-1 > length(dest)
        throw(BoundsError())
    end
    unsafe_copyto!(dest, doffs, src, soffs, n)
end

function Base.unsafe_copyto!(dest::Array{T}, doffs::Integer, src::UnsafeArray{T}, soffs::Integer, n::Integer) where {T}
    @assert isbitstype(T)
    unsafe_copyto!(pointer(dest, doffs), pointer(src, soffs), n)
    return dest
end

Base.copyto!(dest::UnsafeArray{T}, src::Array{T}) where {T} = copyto!(dest, 1, src, 1, length(src))

function Base.copyto!(dest::UnsafeArray{T}, doffs::Integer, src::Array{T}, soffs::Integer, n::Integer) where {T}
    n == 0 && return dest
    n > 0 || throw(ArgumentError(string("tried to copy n=", n, " elements, but n should be nonnegative")))
    if soffs < 1 || doffs < 1 || soffs+n-1 > length(src) || doffs+n-1 > length(dest)
        throw(BoundsError())
    end
    unsafe_copyto!(dest, doffs, src, soffs, n)
end

function Base.unsafe_copyto!(dest::UnsafeArray{T}, doffs::Integer, src::Array{T}, soffs::Integer, n::Integer) where {T}
    @assert isbitstype(T)
    unsafe_copyto!(pointer(dest, doffs), pointer(src, soffs), n)
    return dest
end


Base.deepcopy(A::UnsafeArray) = copyto!(similar(A), A)

function Base.reinterpret(::Type{DST}, A::UnsafeArray{SRC}) where {DST, SRC}
    if sizeof(DST) != sizeof(SRC)
        sz = size(A)
        sz1, rem = divrem(sz[1] * sizeof(SRC), sizeof(DST))
        @boundscheck if rem != zero(rem)
            throw(ArgumentError("Resulting array would have non-integral first dimension"))
        end
        UnsafeArray(convert(Ptr{DST}, pointer(A)), (sz1, Base.tail(sz)...))
    else
        UnsafeArray(convert(Ptr{DST}, pointer(A)), size(A))
    end
end

function Base.reinterpret(::typeof(reshape), ::Type{DST}, A::UnsafeArray{SRC}) where {DST, SRC}
    if sizeof(DST) > sizeof(SRC)
        @boundscheck if size(A, 1) * sizeof(SRC) != sizeof(DST)
            throw(ArgumentError("Cannot reinterpret: first dimension × sizeof(SRC) must exactly match sizeof(DST). Got: size(A, 1) = $(size(A, 1)), sizeof(SRC) = $(sizeof(SRC)), sizeof(DST) = $(sizeof(DST))"))
        end
        UnsafeArray(convert(Ptr{DST}, pointer(A)), Base.tail(size(A)))
    elseif sizeof(DST) < sizeof(SRC)
        @boundscheck if sizeof(DST) == 0 || rem(sizeof(SRC), sizeof(DST)) != 0
            throw(ArgumentError("Cannot reinterpret: sizeof(SRC) must be a multiple of sizeof(DST). Got: sizeof(SRC) = $(sizeof(SRC)), sizeof(DST) = $(sizeof(DST))"))
        end
        sz1 = div(sizeof(SRC), sizeof(DST))
        UnsafeArray(convert(Ptr{DST}, pointer(A)), (sz1, size(A)...))
    else
        UnsafeArray(convert(Ptr{DST}, pointer(A)), size(A))
    end
end

# # Defining Base.unaliascopy results in very bad broadcast performance for
# # some reason, even when it shouldn't be called. By default, unaliascopy
# # results in an error for UnsafeArray.
#
# Base.unaliascopy(A::UnsafeArray) = begin
#     copy(A)
# end
