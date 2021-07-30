import Base: reshape, adjoint, transpose, *, sum

export matmul, linear, reshape, transpose, adjoint, broadcastto, sumto


"""
    MatMul <: Func
"""
@func mutable struct MatMul end

forward(f::MatMul, w, x) = w * x

function backward(f::MatMul, gy)
    w, x = f._inputs
    gw = matmul(gy, transpose(x))
    gx = matmul(transpose(w), gy)
    return gw, gx
end

matmul(w, x) = MatMul()(w, x)

function Base.:*(A::Var, B::Var)
    sizeA, sizeB = size(A), size(B)
    sizeA == sizeB == (1,) && return mul(A, B) # when both A and B is a number
    return matmul(A, B)
end
Base.:*(A::Var, B) = *(A, asvar(B))
Base.:*(A, B::Var) = *(asvar(A), B)


"""
    Reshape <: Func
"""
@func mutable struct Reshape
    shape::Tuple
    Reshape(shape) = new(shape)
end

forward(f::Reshape, x) = reshape(x, f.shape)

backward(f::Reshape, gy) = reshape(gy, size(f._inputs[1]))

function reshape(x, shape...)
    if length(shape) == 1 && shape[1] isa Union{Tuple,AbstractArray}
        shape = shape[1]
    end
    size(x) == shape && return asvar(x)
    return Reshape(shape)(x)
end

adjoint(x::Var) = transpose(x)


"""
    transpose <: Func
"""
@func mutable struct Transpose end

forward(f::Transpose, x) = transpose(x)

backward(f::Transpose, gy) = transpose(gy)

transpose(x::Var) = Transpose()(x)


"""
    Sum <: Func
"""
@func mutable struct Sum
    dims::Union{Int,Tuple,Nothing}
    Sum(dims) = new(dims)
end

function forward(f::Sum, x)
    if f.dims isa Nothing
        return sum(x)
    else
        return sum(x, dims=f.dims)
    end
end

backward(f::Sum, gy) = broadcastto(gy, size(args[1]))

sum(x::Var; dims=nothing) = Sum(dims)(x)


"""
    BroadcastTo <: Func
"""
@func mutable struct BroadcastTo
    shape::Tuple
    BroadcastTo(shape) = new(shape)
end

forward(f::BroadcastTo, x) = x .* ones(f.shape)

backward(f::BroadcastTo, gy) = sumto(gy, size(f._inputs[1]))

broadcastto(x::Var, shape) = size(x) == shape ? asvar(x) : BroadcastTo(shape)(x)


"""
    SumTo <: Func
"""
@func mutable struct SumTo
    shape::Tuple
    SumTo(shape) = new(shape)
end

forward(f::SumTo, x) = _sumto(x, f.shape)

backward(f::SumTo, gy) = broadcastto(gy, size(f._inputs[1]))

sumto(x::Var, shape) = size(x) == shape ? asvar(x) : SumTo(shape)(x)

function _sumto(x, shape)
    target_dim = length(shape)
    lead = ndims(x) - target_dim
    lead_dims = Tuple(target_dim + 1:ndims(x))
    dims = ()
    for i in 1:target_dim
        if shape[i] == 1
            dims = tuple(dims..., i + lead)
        end
    end
    y = sum(x, dims=(lead_dims..., dims...))
    lead > 0 && (y = dropdims(y, dims=lead_dims))
    return y
end