# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).


const IdxRange = AbstractUnitRange{<:Integer}
const SubIdx = Union{IdxRange,Integer}


@inline _sub_size() = ()

@inline _sub_size(i::Integer, inds::SubIdx...) =
    (_sub_size(inds...)...)

@inline _sub_size(r::IdxRange, inds::SubIdx...) =
    (length(r), _sub_size(inds...)...)


@inline _sub_startidxs() = ()

@inline _sub_startidxs(i::Integer, inds::SubIdx...) =
    (i, _sub_startidxs(inds...)...)

@inline _sub_startidxs(r::IdxRange, inds::SubIdx...) =
    (first(r), _sub_startidxs(inds...)...)
