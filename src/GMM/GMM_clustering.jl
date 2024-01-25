"Part of [BetaML](https://github.com/sylvaticus/BetaML.jl). Licence is MIT."

"""
estep(X,pₖ,mixtures)

E-step: assign the posterior prob p(j|xi) and computing the log-Likelihood of the parameters given the set of data (this last one for informative purposes and terminating the algorithm only)
"""
function estep(X,pₖ,mixtures)
 (N,D)  = size(X)
 K      = length(mixtures)
 Xmask  = .! ismissing.(X)
 logpₙₖ = zeros(N,K)
 lL     = 0
 for n in 1:N
     if any(Xmask[n,:]) # if at least one true
         Xu    = X[n,Xmask[n,:]]
         logpx = lse([log(pₖ[k] + 1e-16) + lpdf(mixtures[k],Xu,Xmask[n,:]) for k in 1:K])
         lL += logpx
         for k in 1:K
             logpₙₖ[n,k] = log(pₖ[k] + 1e-16)+lpdf(mixtures[k],Xu,Xmask[n,:])-logpx
         end
     else
         logpₙₖ[n,:] = log.(pₖ)
     end
 end
 pₙₖ = exp.(logpₙₖ)
 return (pₙₖ,lL)
end



## The gmm algorithm (Lecture/segment 16.5 of https://www.edx.org/course/machine-learning-with-python-from-linear-models-to)

# no longer true with the numerical trick implemented
# - For mixtures with full covariance matrix (i.e. `FullGaussian(μ,σ²)`) the minimum_covariance should NOT be set equal to the minimum_variance, or if the covariance matrix goes too low, it will become singular and not invertible.
"""
gmm(X,K;initial_probmixtures,mixtures,tol,verbosity,minimum_variance,minimum_covariance,initialisation_strategy)

Compute Expectation-Maximisation algorithm to identify K clusters of X data, i.e. employ a Generative Mixture Model as the underlying probabilistic model.

!!! warning
    This function is no longer exported. Use one of the various models that use GMM as backend instead.

X can contain missing values in some or all of its dimensions. In such case the learning is done only with the available data.
Implemented in the log-domain for better numerical accuracy with many dimensions.

# Parameters:
* `X`  :           A (n x d) data to clusterise
* `K`  :           Number of cluster wanted
* `initial_probmixtures` :           Initial probabilities of the categorical distribution (K x 1) [default: `[]`]
* `mixtures`:      An array (of length K) of the mixture to employ (see notes) [def: `[DiagonalGaussian() for i in 1:K]`]
* `tol`:           Tolerance to stop the algorithm [default: 10^(-6)]
* `verbosity`:     A verbosity parameter regulating the information messages frequency [def: `STD`]
* `minimum_variance`:   Minimum variance for the mixtures [default: 0.05]
* `minimum_covariance`: Minimum covariance for the mixtures with full covariance matrix [default: 0]. This should be set different than minimum_variance (see notes).
* `initialisation_strategy`:  Mixture initialisation algorithm [def: `kmeans`]
* `maximum_iterations`:       Maximum number of iterations [def: `typemax(Int64)`, i.e. ∞]
* `rng`:           Random Number Generator (see [`FIXEDSEED`](@ref)) [deafult: `Random.GLOBAL_RNG`]

# Returns:
* A named touple of:
* `pₙₖ`:      Matrix of size (N x K) of the probabilities of each point i to belong to cluster j
* `pₖ`:       Probabilities of the categorical distribution (K x 1)
* `mixtures`: Vector (K x 1) of the estimated underlying distributions
* `ϵ`:        Vector of the discrepancy (matrix norm) between pⱼₓ and the lagged pⱼₓ at each iteration
* `lL`:       The log-likelihood (without considering the last mixture optimisation)
* `BIC`:      The Bayesian Information Criterion (lower is better)
* `AIC`:      The Akaike Information Criterion (lower is better)

# Notes:
- The mixtures currently implemented are `SphericalGaussian(μ,σ²)`,`DiagonalGaussian(μ,σ²)` and `FullGaussian(μ,σ²)`
- Reasonable choices for the minimum_variance/Covariance depends on the mixture. For example 0.25 seems a reasonable value for the SphericalGaussian, 0.05 seems better for the DiagonalGaussian, and FullGaussian seems to prefer either very low values of variance/covariance (e.g. `(0.05,0.05)` ) or very big but similar ones (e.g. `(100,100)` ).
- For `initialisation_strategy`, look at the documentation of `init_mixtures!` for the mixture you want. The provided gaussian mixtures support `grid`, `kmeans` or `given`. `grid` is faster (expecially if X contains missing values), but `kmeans` often provides better results.

# Resources:
- [Paper describing gmm with missing values](https://doi.org/10.1016/j.csda.2006.10.002)
- [Class notes from MITx 6.86x (Sec 15.9)](https://stackedit.io/viewer#!url=https://github.com/sylvaticus/MITx_6.86x/raw/master/Unit 04 - Unsupervised Learning/Unit 04 - Unsupervised Learning.md)
- [Limitations of gmm](https://www.r-craft.org/r-news/when-not-to-use-gaussian-mixture-model-gmm-clustering/)

# Example:
```julia
julia> clusters = gmm([1 10.5;1.5 0; 1.8 8; 1.7 15; 3.2 40; 0 0; 3.3 38; 0 -2.3; 5.2 -2.4],3,verbosity=HIGH)
```
"""
function gmm(X,K;initial_probmixtures=Float64[],mixtures=[DiagonalGaussian() for i in 1:K],tol=10^(-6),verbosity=STD,minimum_variance=0.05,minimum_covariance=0.0,initialisation_strategy="kmeans",maximum_iterations=typemax(Int64),rng = Random.GLOBAL_RNG)
# TODO: benchmark with this one: https://bmcbioinformatics.biomedcentral.com/articles/10.1186/s12859-022-04740-9 
 if verbosity > STD
     @codelocation
 end
 # debug:
 #X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
 #K = 3
 #initial_probmixtures=nothing; tol=0.0001; msgStep=1; minimum_variance=0.25; initialisation_strategy="grid"
 #mixtures = [SphericalGaussian() for i in 1:K]
 # ---------
 X     = makematrix(X)
 (N,D) = size(X)
 pₖ    = isempty(initial_probmixtures) ? fill(1/K,K) : copy(initial_probmixtures)

 # no longer true with the numerical trick implemented
 #if (minimum_variance == minimum_covariance)
 #    @warn("Setting the minimum_variance equal to the minimum_covariance may lead to singularity problems for mixtures with full covariance matrix.")
 #end

 msgStepMap = Dict(NONE => 0, LOW=>100, STD=>20, HIGH=>5, FULL=>1)
 msgStep    = msgStepMap[verbosity]


 # Initialisation of the parameters of the mixtures
 mixtures = identity.(deepcopy(mixtures)) # to set the container to the minimum common denominator of element types the deepcopy is not to change the function argument
 #mixtures = identity.(mixtures) 

 init_mixtures!(mixtures,X,minimum_variance=minimum_variance,minimum_covariance=minimum_covariance,initialisation_strategy=initialisation_strategy,rng=rng)

 pₙₖ = zeros(Float64,N,K) # The posteriors, i.e. the prob that item n belong to cluster k
 ϵ = Float64[]

 # Checking dimensions only once (but adding then inbounds doesn't change anything. Still good
 # to provide a nice informative message)
 if size(pₖ,1) != K || length(mixtures) != K
     error("Error in the dimensions of the inputs. Please check them.")
 end

 # finding empty/non_empty values
 #Xmask     =  .! ismissing.(X)

 lL = -Inf
 iter = 1
 while(true)
     oldlL = lL
     # E Step: assigning the posterior prob p(j|xi) and computing the log-Likelihood of the parameters given the set of data
     pₙₖlagged = copy(pₙₖ)
     pₙₖ, lL = estep(X,pₖ,mixtures) 
     push!(ϵ,norm(pₙₖlagged - pₙₖ))

     # M step: find parameters that maximise the likelihood
     # Updating the probabilities of the different mixtures
     nₖ = sum(pₙₖ,dims=1)'
     n  = sum(nₖ)
     pₖ = nₖ ./ n
     update_parameters!(mixtures, X, pₙₖ; minimum_variance=minimum_variance,minimum_covariance=minimum_covariance)

     # Information. Note the likelihood is whitout accounting for the new mu, sigma
     if msgStep != 0 && (length(ϵ) % msgStep == 0 || length(ϵ) == 1)
         println("Iter. $(length(ϵ)):\tVar. of the post  $(ϵ[end]) \t  Log-likelihood $(lL)")
     end

     # Closing conditions. Note that the logLikelihood is those without considering the new mu,sigma
     if ((lL - oldlL) <= (tol * abs(lL))) || (iter >= maximum_iterations)
         npars = npar(mixtures) + (K-1)
         #BIC  = lL - (1/2) * npars * log(N)
         BICv = bic(lL,npars,N)
         AICv = aic(lL,npars)
     #if (ϵ[end] < tol)
        return (pₙₖ=pₙₖ,pₖ=pₖ,mixtures=mixtures,ϵ=ϵ,lL=lL,BIC=BICv,AIC=AICv)
    else
         iter += 1
    end
 end # end while loop
end # end function

#  - For mixtures with full covariance matrix (i.e. `FullGaussian(μ,σ²)`) the minimum_covariance should NOT be set equal to the minimum_variance, or if the covariance matrix goes too low, it will become singular and not invertible.


# Avi v2..

"""
$(TYPEDEF)

Hyperparameters for GMM clusters and other GMM-based algorithms

## Parameters:
$(FIELDS)

"""
mutable struct GaussianMixture_hp <: BetaMLHyperParametersSet
    "Number of mixtures (latent classes) to consider [def: 3]"
    n_classes::Int64
    "Initial probabilities of the categorical distribution (n_classes x 1) [default: `[]`]"
    initial_probmixtures::Vector{Float64}
    """An array (of length `n_classes`) of the mixtures to employ (see the [`?GMM`](@ref GMM) module).
    Each mixture object can be provided with or without its parameters (e.g. mean and variance for the gaussian ones). Fully qualified mixtures are useful only if the `initialisation_strategy` parameter is  set to \"gived\".
    This parameter can also be given symply in term of a _type_. In this case it is automatically extended to a vector of `n_classes` mixtures of the specified type.
    Note that mixing of different mixture types is not currently supported and that currently implemented mixtures are `SphericalGaussian`, `DiagonalGaussian` and `FullGaussian`.
    [def: `DiagonalGaussian`]"""
    mixtures::Union{Type,Vector{<: AbstractMixture}}
    "Tolerance to stop the algorithm [default: 10^(-6)]"
    tol::Float64
    "Minimum variance for the mixtures [default: 0.05]"
    minimum_variance::Float64
    "Minimum covariance for the mixtures with full covariance matrix [default: 0]. This should be set different than minimum_variance."
    minimum_covariance::Float64
    """
    The computation method of the vector of the initial mixtures.
    One of the following:
    - "grid": using a grid approach
    - "given": using the mixture provided in the fully qualified `mixtures` parameter
    - "kmeans": use first kmeans (itself initialised with a "grid" strategy) to set the initial mixture centers [default]
    Note that currently "random" and "shuffle" initialisations are not supported in gmm-based algorithms.
    """
    initialisation_strategy::String
    "Maximum number of iterations [def: 5000]"
    maximum_iterations::Int64
    """
    The method - and its parameters - to employ for hyperparameters autotuning.
    See [`SuccessiveHalvingSearch`](@ref) for the default method (suitable for the GMM-based regressors)
    To implement automatic hyperparameter tuning during the (first) `fit!` call simply set `autotune=true` and eventually change the default `tunemethod` options (including the parameter ranges, the resources to employ and the loss function to adopt).
    """
    tunemethod::AutoTuneMethod

    function GaussianMixture_hp(;
        n_classes::Union{Nothing,Int64}                  = nothing, # def: 3
        initial_probmixtures::Vector{Float64}            = Float64[],
        mixtures::Union{Type,Vector{<: AbstractMixture},Nothing} = nothing, # DiagonalGaussian
        tol::Float64                                     = 10^(-6),
        minimum_variance::Float64                        = 0.05,
        minimum_covariance::Float64                      = 0.0,
        initialisation_strategy::String                  = "kmeans",
        maximum_iterations::Int64                        = 5000,
        tunemethod::AutoTuneMethod                       = SuccessiveHalvingSearch(
            hpranges = Dict("n_classes" =>[2,3,4,5,6],
                            "mixtures"=>[SphericalGaussian,DiagonalGaussian,FullGaussian],
                            "initialisation_strategy"=>["grid","kmeans"],
                            "minimum_covariance"=>[0.01,0.02],
                            "minimum_variance"=>[0.05,0.07,0.1])
            ,multithreads=true)
        )
        if isnothing(mixtures) && isnothing(n_classes)
            n_classes = 3
            mixtures = [DiagonalGaussian() for i in 1:3]
        elseif isnothing(mixtures) && !isnothing(n_classes)
            mixtures = [DiagonalGaussian() for i in 1:n_classes]
        elseif typeof(mixtures) <: UnionAll && isnothing(n_classes)
            n_classes = 3
            mixtures = [mixtures() for i in 1:n_classes]
        elseif typeof(mixtures) <: UnionAll && !isnothing(n_classes)
            mixtures = [mixtures() for i in 1:n_classes]
        elseif typeof(mixtures) <: AbstractVector && isnothing(n_classes)
            println("sfsdfsdf")
            n_classes = length(mixtures)
        elseif typeof(mixtures) <: AbstractVector && !isnothing(n_classes)
            n_classes == length(mixtures) || error("The length of the mixtures vector must be equal to the number of classes")
        end
        return new(n_classes,initial_probmixtures,mixtures,tol,minimum_variance,minimum_covariance,initialisation_strategy,maximum_iterations,tunemethod)        
    end
end


Base.@kwdef mutable struct GMMCluster_lp <: BetaMLLearnableParametersSet
    mixtures::Union{Type,Vector{<: AbstractMixture}}    = AbstractMixture[] # attention that this is set up at model construction, as it has the same name as the hyperparameter
    initial_probmixtures::Vector{Float64}               = []
    #probRecords::Union{Nothing,Matrix{Float64}} = nothing
end

"""
$(TYPEDEF)

Assign class probabilities to records (i.e. _soft_ clustering) assuming a probabilistic generative model of observed data using mixtures.

For the parameters see [`?GaussianMixture_hp`](@ref GaussianMixture_hp) and [`?BML_options`](@ref BML_options).

# Notes:
- Data must be numerical
- Mixtures can be user defined: see the [`?GMM`](@ref GMM) module documentation for a discussion on provided vs custom mixtures.
- Online fitting (re-fitting with new data) is supported by setting the old learned mixtrures as the starting values
- The model is fitted using an Expectation-Minimisation (EM) algorithm that supports Missing data and is implemented in the log-domain for better numerical accuracy with many dimensions

# Example: 
```julia
julia> using BetaML

julia> X = [1.1 10.1; 0.9 9.8; 10.0 1.1; 12.1 0.8; 0.8 9.8];

julia> mod = GaussianMixtureClusterer(n_classes=2)
GaussianMixtureClusterer - A Generative Mixture Model (unfitted)

julia> prob_belong_classes = fit!(mod,X)
Iter. 1:        Var. of the post  2.15612140465882        Log-likelihood -29.06452054772657
5×2 Matrix{Float64}:
 1.0  0.0
 1.0  0.0
 0.0  1.0
 0.0  1.0
 1.0  0.0

julia> new_probs = fit!(mod,[11 0.9])
Iter. 1:        Var. of the post  1.0     Log-likelihood -1.3312256125240092
1×2 Matrix{Float64}:
 0.0  1.0

julia> info(mod)
Dict{String, Any} with 6 entries:
  "xndims"         => 2
  "error"          => [1.0, 0.0, 0.0]
  "AIC"            => 15.7843
  "fitted_records" => 6
  "lL"             => 1.10786
  "BIC"            => -2.21571

julia> parameters(mod)
BetaML.GMM.GMMCluster_lp (a BetaMLLearnableParametersSet struct)
- mixtures: DiagonalGaussian{Float64}[DiagonalGaussian{Float64}([0.9333333333333332, 9.9], [0.05, 0.05]), DiagonalGaussian{Float64}([11.05, 0.9500000000000001], [0.05, 0.05])]
- initial_probmixtures: [0.0, 1.0]
```
"""
mutable struct GaussianMixtureClusterer <: BetaMLUnsupervisedModel
    hpar::GaussianMixture_hp
    opt::BML_options
    par::Union{Nothing,GMMCluster_lp}
    cres::Union{Nothing,Matrix{Float64}}
    fitted::Bool
    info::Dict{String,Any}
end

function GaussianMixtureClusterer(;kwargs...)
     m = GaussianMixtureClusterer(GaussianMixture_hp(),BML_options(),GMMCluster_lp(),nothing,false,Dict{Symbol,Any}())
    thisobjfields  = fieldnames(nonmissingtype(typeof(m)))
    for (kw,kwv) in kwargs
       found = false
       for f in thisobjfields
          fobj = getproperty(m,f)
          if kw in fieldnames(typeof(fobj))
              setproperty!(fobj,kw,kwv)
              found = true
          end
        end
        found || error("Keyword \"$kw\" is not part of this model.")
    end
    
    # Special correction for GaussianMixture_hp
    kwkeys = keys(kwargs) #in(2,[1,2,3])
    if !in(:mixtures,kwkeys) && !in(:n_classes,kwkeys)
        m.hpar.n_classes = 3
        m.hpar.mixtures = [DiagonalGaussian() for i in 1:3]
    elseif !in(:mixtures,kwkeys) && in(:n_classes,kwkeys)
        m.hpar.mixtures = [DiagonalGaussian() for i in 1:kwargs[:n_classes]]
    elseif typeof(kwargs[:mixtures]) <: UnionAll && !in(:n_classes,kwkeys)
        m.hpar.n_classes = 3
        m.hpar.mixtures = [kwargs[:mixtures]() for i in 1:3]
    elseif typeof(kwargs[:mixtures]) <: UnionAll && in(:n_classes,kwkeys)
        m.hpar.mixtures = [kwargs[:mixtures]() for i in 1:kwargs[:n_classes]]
    elseif typeof(kwargs[:mixtures]) <: AbstractVector && !in(:n_classes,kwkeys)
        m.hpar.n_classes = length(kwargs[:mixtures])
    elseif typeof(kwargs[:mixtures]) <: AbstractVector && in(:n_classes,kwkeys)
        kwargs[:n_classes] == length(kwargs[:mixtures]) || error("The length of the mixtures vector must be equal to the number of classes")
    end

    return m
end

"""
$(TYPEDSIGNATURES)

Fit the [`GaussianMixtureClusterer`](@ref) model to data

# Notes:
- re-fitting is a new complete fitting but starting with mixtures computed in the previous fitting(s)
"""
function fit!(m::GaussianMixtureClusterer,x)

    # Parameter alias..
    K             = m.hpar.n_classes
    initial_probmixtures            = m.hpar.initial_probmixtures
    mixtures      = m.hpar.mixtures
    if  typeof(mixtures) <: UnionAll
        mixtures = [mixtures() for i in 1:K]
    end
    tol           = m.hpar.tol
    minimum_variance   = m.hpar.minimum_variance
    minimum_covariance = m.hpar.minimum_covariance
    initialisation_strategy  = m.hpar.initialisation_strategy
    maximum_iterations       = m.hpar.maximum_iterations
    cache         = m.opt.cache
    verbosity     = m.opt.verbosity
    rng           = m.opt.rng

    if m.fitted
        verbosity >= HIGH  && @info "Continuing training of a pre-fitted model"
        gmmOut = gmm(x,K;initial_probmixtures=m.par.initial_probmixtures,mixtures=m.par.mixtures,tol=tol,verbosity=verbosity,minimum_variance=minimum_variance,minimum_covariance=minimum_covariance,initialisation_strategy="given",maximum_iterations=maximum_iterations,rng = rng)
    else
        gmmOut = gmm(x,K;initial_probmixtures=initial_probmixtures,mixtures=mixtures,tol=tol,verbosity=verbosity,minimum_variance=minimum_variance,minimum_covariance=minimum_covariance,initialisation_strategy=initialisation_strategy,maximum_iterations=maximum_iterations,rng = rng)
    end
    probRecords = gmmOut.pₙₖ
    m.par  = GMMCluster_lp(mixtures = gmmOut.mixtures, initial_probmixtures=makecolvector(gmmOut.pₖ))

    m.cres = cache ? probRecords : nothing
    m.info["error"]          = gmmOut.ϵ
    m.info["lL"]             = gmmOut.lL
    m.info["BIC"]            = gmmOut.BIC
    m.info["AIC"]            = gmmOut.AIC
    m.info["fitted_records"] = get(m.info,"fitted_records",0) + size(x,1)
    m.info["xndims"]     = size(x,2)
    m.fitted=true
    return cache ? m.cres : nothing
end    

"""
$(TYPEDSIGNATURES)

Predict the classes probabilities associated to new data assuming the mixtures computed in fitting a [`GaussianMixtureClusterer`](@ref) model.

"""
function predict(m::GaussianMixtureClusterer,X)
    X = makematrix(X)
    mixtures = m.par.mixtures
    initial_probmixtures = m.par.initial_probmixtures
    probRecords, lL = estep(X,initial_probmixtures,mixtures)
    return probRecords
end

function show(io::IO, ::MIME"text/plain", m::GaussianMixtureClusterer)
    if m.fitted == false
        print(io,"GaussianMixtureClusterer - A Generative Mixture Model (unfitted)")
    else
        print(io,"GaussianMixtureClusterer - A Generative Mixture Model (fitted on $(m.info["fitted_records"]) records)")
    end
end

function show(io::IO, m::GaussianMixtureClusterer)
    m.opt.descr != "" && println(io,m.opt.descr)
    if m.fitted == false
        print(io,"GaussianMixtureClusterer - A $(m.hpar.n_classes)-classes Generative Mixture Model (unfitted)")
    else
        print(io,"GaussianMixtureClusterer - A $(m.hpar.n_classes)-classes Generative Mixture Model(fitted on $(m.info["fitted_records"]) records)")
        println(io,m.info)
        println(io,"Mixtures:")
        println(io,m.par.mixtures)
        println(io,"Probability of each mixture:")
        println(io,m.par.initial_probmixtures)
    end
end