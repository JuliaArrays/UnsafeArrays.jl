# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).


const IdxRange = AbstractUnitRange{<:Integer}
const SubIdx = Union{IdxRange,Integer}


@inline _sub_size(S...) = _sub_size_impl((), S...)

@inline _sub_size_impl(result) =
    (result...)

@inline _sub_size_impl(result, i::Integer, I::SubIdx...) =
    _sub_size_impl(result, I...)

@inline _sub_size_impl(result, r::IdxRange, I::SubIdx...) =
    _sub_size_impl((result..., length(r)), I...)


@inline _sub_startidxs(IA::Tuple, I...) =
    _sub_startidxs_impl((), IA, I...)

@inline _sub_startidxs_impl(result, IA::Tuple) =
    (result...)

@inline _sub_startidxs_impl(result, IA::Tuple, i::Integer, is::Integer...) =
    (result..., Int(i), map(Int, is)...)

@inline function _sub_startidxs_impl(result, IA::Tuple, i::Integer, I::SubIdx...)
    if IA[1] != i:i
        _check_single_idxs_sel_only(I...)
    end
    _sub_startidxs_impl((result..., Int(i)), Base.tail(IA), I...)
end

@inline _sub_startidxs_impl(result, IA::Tuple, r::IdxRange, is::Integer...) =
    _sub_startidxs_impl((result..., Int(first(r))), Base.tail(IA), is...)

@inline function _sub_startidxs_impl(result, IA::Tuple, r::IdxRange, I::SubIdx...)
    if IA[1] != r
        _check_single_idxs_sel_only(I...)
    end
    _sub_startidxs_impl((result..., Int(first(r))), Base.tail(IA), I...)
end

@inline _sub_startidxs_impl(result, IA::Tuple, r::Base.Slice, I::SubIdx...) =
    _sub_startidxs_impl((result..., Int(first(r))), Base.tail(IA), I...)


function _check_single_idxs_sel_only(I::SubIdx...)
    for idxs in I
        length(idxs) == 1 || throw(ArgumentError("Sub-array must be dense"))
    end
    nothing
end
