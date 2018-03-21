# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).


const IdxUnitRange = AbstractUnitRange{<:Integer}
const DenseIdx = Union{IdxUnitRange,Integer}


@static if VERSION < v"0.7.0-DEV.3025"
    # LinearIndices(dims...)[I...] is slow on Julia v0.6, use sub2ind instead:
    Base.@propagate_inbounds _fast_sub2ind(dims::Dims{N}, I::Vararg{Integer,N}) where {N} = sub2ind(dims, I...)
else
    Base.@propagate_inbounds _fast_sub2ind(dims::Dims{N}, I::Vararg{Integer,N}) where {N}  = LinearIndices(dims)[I...]
end


@inline _sub_size(S...) = _sub_size_impl((), S...)

@inline _sub_size_impl(result) =
    (result...)

@inline _sub_size_impl(result, i::Integer, I::DenseIdx...) =
    _sub_size_impl(result, I...)

@inline _sub_size_impl(result, r::IdxUnitRange, I::DenseIdx...) =
    _sub_size_impl((result..., length(r)), I...)


function _require_one_based_indexing(A::AbstractArray{T,N}) where {T,N}
    typeof(axes(A)) == NTuple{N,Base.OneTo{Int}} || throw(ArgumentError("Parent array must have one-based indexing"))
    nothing
end
