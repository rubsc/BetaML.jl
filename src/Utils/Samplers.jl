"Part of [BetaML](https://github.com/sylvaticus/BetaML.jl). Licence is MIT."

import Base.iterate
abstract type  AbstractDataSampler end

"""
  SamplerWithData{Tsampler}

Associate an instance of an AbstractDataSampler with the actual data to sample.

"""
mutable struct SamplerWithData{Ts <: AbstractDataSampler, Td <: AbstractArray}
    sampler::Ts
    data::Td
    dims::Int64
end

# To implement a new sampler:
# - create a new structure child of AbstractDataSampler
# - override iterate(iter::SamplerWithData{yoursampler} and iterate(iter::SamplerWithData{yoursampler},state) considering that
#=
for i in iter   # or  "for i = iter"
    # body
end

# --> is rewritten to :

next = iterate(iter)
while next !== nothing
    (i, state) = next
    # body
    next = iterate(iter, state)
end
=#
"""
   KFold(nsplits=5,nrepeats=1,shuffle=true,rng=Random.GLOBAL_RNG)

Iterator for k-fold cross_validation strategy.

"""
mutable struct KFold <: AbstractDataSampler
    nsplits::Int64
    nrepeats::Int64
    shuffle::Bool
    rng::AbstractRNG
    function KFold(;nsplits=5,nrepeats=1,shuffle=true,rng=Random.GLOBAL_RNG)
        return new(nsplits,nrepeats,shuffle,rng)
    end
end

# Implementation of the Julia iteration  API for SamplerWithData{KFold}
function iterate(iter::SamplerWithData{KFold})
     # First iteration, I need to create the subsamples
     K    = iter.sampler.nsplits
     D    = iter.dims
     if eltype(iter.data) <: AbstractArray # data has multiple arrays, like X,Y
       subs = collect(zip(partition(iter.data,fill(1/K,K),shuffle=iter.sampler.shuffle,dims=D,rng=iter.sampler.rng,copy=false)...))
     else # data is a single matrix/tensor
       subs = collect(zip(partition(iter.data,fill(1/K,K),shuffle=iter.sampler.shuffle,dims=D,rng=iter.sampler.rng,copy=false)))
     end
     i    = (cat.(subs[2:K]...,dims=D),subs[1])
     next = (subs,2)
     return (i,next)
end

function iterate(iter::SamplerWithData{KFold},state)
     # Further iteration, I need to create the subsamples only if it is a new interaction
     K    = iter.sampler.nsplits
     D    = iter.dims
     nRep = iter.sampler.nrepeats
     subs    = state[1]
     counter = state[2]
     counter <= (K * nRep) || return nothing  # If we are done all the splits by the repetitions we are done
     kpart = counter % K
     if kpart == 1 # new round, we repartition in k parts
         if eltype(iter.data) <: AbstractArray # data has multiple arrays, like X,Y
             subs = collect(zip(partition(iter.data,fill(1/K,K),shuffle=iter.sampler.shuffle,dims=D,rng=iter.sampler.rng,copy=false)...))
         else # data is a single matrix
             subs = collect(zip(partition(iter.data,fill(1/K,K),shuffle=iter.sampler.shuffle,dims=D,rng=iter.sampler.rng,copy=false)))
         end
         i    = (cat.(subs[2:end]...,dims=D),subs[1])
         next = (subs,counter+1)
         return (i,next)
     else
        if kpart == 0 # the modulo returns the last element as zero instead as K
            i   = (cat.(subs[1:K-1]...,dims=D),subs[end])
        else
            i   = (cat.(subs[1:kpart-1]...,subs[kpart+1:end]...,dims=D),subs[kpart])
        end
        next  = (subs,counter+1)
        return (i,next)
    end
end


# ------------------------------------------------------------------------------
# Used for NN
"""
  batch(n,bsize;sequential=false,rng)

Return a vector of `bsize` vectors of indeces from `1` to `n`.
Randomly unless the optional parameter `sequential` is used.

# Example:
```julia
julia> Utils.batch(6,2,sequential=true)
3-element Array{Array{Int64,1},1}:
 [1, 2]
 [3, 4]
 [5, 6]
 ```
"""
function batch(n::Integer,bsize::Integer;sequential=false,rng = Random.GLOBAL_RNG)
    ridx = sequential ? collect(1:n) : shuffle(rng,1:n)
    if bsize > n
        return [ridx]
    end
    n_batches = Int64(floor(n/bsize))
    batches = Array{Int64,1}[]
    for b in 1:n_batches
        push!(batches,ridx[b*bsize-bsize+1:b*bsize])
    end
    return batches
end


"""
$(TYPEDSIGNATURES)

PErform a Xavier initialisation of the weigths

# Parameters:
- `previous_npar`: number of parameters of the previous layer
- `this_npar`: number of parameters of this layer
- `outsize`: tuple with the size of the weigths [def: `(this_npar,previous_npar)`]
- `rng` : random number generator [def: `Random.GLOBAL_RNG`]
- `eltype`: eltype of the weigth array [def: `Float64`]

"""
function xavier_init(previous_npar,this_npar,outsize=(this_npar,previous_npar);rng=Random.GLOBAL_RNG,eltype=Float64)
    out = rand(rng, Uniform(-sqrt(6)/sqrt(previous_npar+this_npar),sqrt(6)/sqrt(previous_npar+this_npar)),outsize)
    if eltype != Float64
        return convert(Array{eltype,length(outsize)},out)
    else
        return out
    end
end
