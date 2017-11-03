# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).


_back_impl(x, xs...) = xs
_back_impl() = ()
_back(t::Tuple) = _back_impl(t...)


const IdxRange = UnitRange{<:Integer}
const SubIdx = Union{Colon,UnitRange{<:Integer},Integer}


_sub_size_impl(s::NTuple{N,Integer}, ::Colon, inds::SubIdx...) where {N} =
    (s[1], _sub_size_impl(_back(s), inds...)...)

_sub_size_impl(s::NTuple{N,Integer}, r::IdxRange, inds::Integer...) where {N} =
    (length(r),)

_sub_size_impl(s::NTuple{N,Integer}, inds::Integer...) where {N} = ()

_sub_size(s::NTuple{N,Integer}, inds::Vararg{SubIdx,N}) where {N} =
    _sub_size_impl(s, inds...)



_sub_startidx() = ()

_sub_startidx(::Colon, inds::SubIdx...) =
    (1, _sub_startidx(inds...)...)

_sub_startidx(r::UnitRange{<:Integer}, inds::Integer...) =
    (first(r), _sub_startidx(inds...)...)

_sub_startidx(i::Integer, inds::Integer...) = (i, inds...)
