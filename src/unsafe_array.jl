# This file is a part of ArrayVectors.jl, licensed under the MIT License (MIT).

const UnsafeArray{T,N} = Union{DenseUnsafeArray{T,N}}

export UnsafeArray


function uview end
export uview
