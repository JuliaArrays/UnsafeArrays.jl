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
    (result...,)

@inline _sub_size_impl(result, i::Integer, I::DenseIdx...) =
    _sub_size_impl(result, I...)

@inline _sub_size_impl(result, r::IdxUnitRange, I::DenseIdx...) =
    _sub_size_impl((result..., length(r)), I...)


function _require_one_based_indexing(A::AbstractArray{T,N}) where {T,N}
    typeof(axes(A)) == NTuple{N,Base.OneTo{Int}} || throw(ArgumentError("Parent array must have one-based indexing"))
    nothing
end


@noinline function _noinline_nop(x::Tuple)
    nothing
end


"""
    UnsafeArrays.@gc_preserve A B ... expr

Protect `A`, `B`, ... from garbage collection while executing `expr`. Contrary
to `GC.@preserve`, expr is executed in a new scope.

Equivalent to

```
GC.@preserve A B ... let
    expr
end
```

On Julia versions that do not provide `GC.@preserve`, a fallback
implementation is used.
"""
macro gc_preserve(args...)
    syms = args[1:end-1]
    expr = args[end]

    for s in syms
        s isa Symbol || error("@gc_preserve targets must be a symbols")
    end

    @static if VERSION >= v"0.7.0-DEV.3465"
        esc(:(GC.@preserve $(syms...) $(Expr(:let, Expr(:block), expr))))
    else
        esc(quote
            try
                $expr
            finally
                $(Expr(:call, :(UnsafeArrays._noinline_nop), syms))
            end
        end)
    end
end
