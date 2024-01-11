"Part of [BetaML](https://github.com/sylvaticus/BetaML.jl). Licence is MIT."

# MLJ interface for clustering models

import MLJModelInterface       # It seems that having done this in the top module is not enought
const MMI = MLJModelInterface  # We need to repeat it here

export  GaussianMixtureClusterer, GaussianMixtureRegressor, MultitargetGaussianMixtureRegressor

# ------------------------------------------------------------------------------
# Model Structure declarations..

"""
$(TYPEDEF)

A Expectation-Maximisation clustering algorithm with customisable mixtures, from the Beta Machine Learning Toolkit (BetaML).

# Hyperparameters:
$(TYPEDFIELDS)

# Example:
```julia

julia> using MLJ

julia> X, y        = @load_iris;

julia> modelType   = @load GaussianMixtureClusterer pkg = "BetaML" verbosity=0
BetaML.GMM.GaussianMixtureClusterer

julia> model       = modelType()
GaussianMixtureClusterer(
  n_classes = 3, 
  initial_probmixtures = Float64[], 
  mixtures = BetaML.GMM.DiagonalGaussian{Float64}[BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing), BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing), BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing)], 
  tol = 1.0e-6, 
  minimum_variance = 0.05, 
  minimum_covariance = 0.0, 
  initialisation_strategy = "kmeans", 
  maximum_iterations = 9223372036854775807, 
  rng = Random._GLOBAL_RNG())

julia> mach        = machine(model, X);

julia> fit!(mach);
[ Info: Training machine(GaussianMixtureClusterer(n_classes = 3, …), …).
Iter. 1:        Var. of the post  10.800150114964184      Log-likelihood -650.0186451891216

julia> classes_est = predict(mach, X)
150-element CategoricalDistributions.UnivariateFiniteVector{Multiclass{3}, Int64, UInt32, Float64}:
 UnivariateFinite{Multiclass{3}}(1=>1.0, 2=>4.17e-15, 3=>2.1900000000000003e-31)
 UnivariateFinite{Multiclass{3}}(1=>1.0, 2=>1.25e-13, 3=>5.87e-31)
 UnivariateFinite{Multiclass{3}}(1=>1.0, 2=>4.5e-15, 3=>1.55e-32)
 UnivariateFinite{Multiclass{3}}(1=>1.0, 2=>6.93e-14, 3=>3.37e-31)
 ⋮
 UnivariateFinite{Multiclass{3}}(1=>5.39e-25, 2=>0.0167, 3=>0.983)
 UnivariateFinite{Multiclass{3}}(1=>7.5e-29, 2=>0.000106, 3=>1.0)
 UnivariateFinite{Multiclass{3}}(1=>1.6e-20, 2=>0.594, 3=>0.406)
```
"""
mutable struct GaussianMixtureClusterer <: MMI.Unsupervised
  "Number of mixtures (latent classes) to consider [def: 3]"  
  n_classes::Int64
  "Initial probabilities of the categorical distribution (n_classes x 1) [default: `[]`]"
  initial_probmixtures::AbstractArray{Float64,1}
  """An array (of length `n_classes`) of the mixtures to employ (see the [`?GMM`](@ref GMM) module).
    Each mixture object can be provided with or without its parameters (e.g. mean and variance for the gaussian ones). Fully qualified mixtures are useful only if the `initialisation_strategy` parameter is set to \"gived\".
    This parameter can also be given symply in term of a _type_. In this case it is automatically extended to a vector of `n_classes` mixtures of the specified type.
    Note that mixing of different mixture types is not currently supported.
    [def: `[DiagonalGaussian() for i in 1:n_classes]`]"""
  mixtures::Union{Type,Vector{<: AbstractMixture}}
  "Tolerance to stop the algorithm [default: 10^(-6)]"
  tol::Float64
  "Minimum variance for the mixtures [default: 0.05]"
  minimum_variance::Float64
  "Minimum covariance for the mixtures with full covariance matrix [default: 0]. This should be set different than minimum_variance (see notes)."
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
  "Maximum number of iterations [def: `typemax(Int64)`, i.e. ∞]"
  maximum_iterations::Int64
  "Random Number Generator [deafult: `Random.GLOBAL_RNG`]"
  rng::AbstractRNG
end
function GaussianMixtureClusterer(;
    n_classes             = 3,
    initial_probmixtures            = Float64[],
    mixtures      = [DiagonalGaussian() for i in 1:n_classes],
    tol           = 10^(-6),
    minimum_variance   = 0.05,
    minimum_covariance = 0.0,
    initialisation_strategy  = "kmeans",
    maximum_iterations       = typemax(Int64),
    rng           = Random.GLOBAL_RNG,
)
    if typeof(mixtures) <: UnionAll
        mixtures = [mixtures() for i in 1:n_classes]
    end
    return GaussianMixtureClusterer(n_classes,initial_probmixtures,mixtures, tol, minimum_variance, minimum_covariance,initialisation_strategy,maximum_iterations,rng)
end

"""
$(TYPEDEF)

A non-linear regressor derived from fitting the data on a probabilistic model (Gaussian Mixture Model). Relatively fast but generally not very precise, except for data with a structure matching the chosen underlying mixture.

This is the single-target version of the model. If you want to predict several labels (y) at once, use the MLJ model [`MultitargetGaussianMixtureRegressor`](@ref).

# Hyperparameters:
$(TYPEDFIELDS)

# Example:
```julia
julia> using MLJ

julia> X, y      = @load_boston;

julia> modelType = @load GaussianMixtureRegressor pkg = "BetaML" verbosity=0
BetaML.GMM.GaussianMixtureRegressor

julia> model     = modelType()
GaussianMixtureRegressor(
  n_classes = 3, 
  initial_probmixtures = Float64[], 
  mixtures = BetaML.GMM.DiagonalGaussian{Float64}[BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing), BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing), BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing)], 
  tol = 1.0e-6, 
  minimum_variance = 0.05, 
  minimum_covariance = 0.0, 
  initialisation_strategy = "kmeans", 
  maximum_iterations = 9223372036854775807, 
  rng = Random._GLOBAL_RNG())

julia> mach      = machine(model, X, y);

julia> fit!(mach);
[ Info: Training machine(GaussianMixtureRegressor(n_classes = 3, …), …).
Iter. 1:        Var. of the post  21.74887448784976       Log-likelihood -21687.09917379566

julia> ŷ         = predict(mach, X)
506-element Vector{Float64}:
 24.703442835305577
 24.70344283512716
  ⋮
 17.172486989759676
 17.172486989759644
```
"""
mutable struct GaussianMixtureRegressor <: MMI.Deterministic
    "Number of mixtures (latent classes) to consider [def: 3]"
    n_classes::Int64 
    "Initial probabilities of the categorical distribution (n_classes x 1) [default: `[]`]"
    initial_probmixtures::Vector{Float64}
    """An array (of length `n_classes``) of the mixtures to employ (see the [`?GMM`](@ref GMM) module).
    Each mixture object can be provided with or without its parameters (e.g. mean and variance for the gaussian ones). Fully qualified mixtures are useful only if the `initialisation_strategy` parameter is  set to \"gived\"`
    This parameter can also be given symply in term of a _type_. In this case it is automatically extended to a vector of `n_classes`` mixtures of the specified type.
    Note that mixing of different mixture types is not currently supported.
    [def: `[DiagonalGaussian() for i in 1:n_classes]`]"""
    mixtures::Union{Type,Vector{<: AbstractMixture}}
    "Tolerance to stop the algorithm [default: 10^(-6)]"
    tol::Float64
    "Minimum variance for the mixtures [default: 0.05]"
    minimum_variance::Float64
    "Minimum covariance for the mixtures with full covariance matrix [default: 0]. This should be set different than minimum_variance (see notes)."
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
    "Maximum number of iterations [def: `typemax(Int64)`, i.e. ∞]"
    maximum_iterations::Int64
    "Random Number Generator [deafult: `Random.GLOBAL_RNG`]"
    rng::AbstractRNG
end
function GaussianMixtureRegressor(;
    n_classes      = 3,
    initial_probmixtures  = [],
    mixtures      = [DiagonalGaussian() for i in 1:n_classes],
    tol           = 10^(-6),
    minimum_variance   = 0.05,
    minimum_covariance = 0.0,
    initialisation_strategy  = "kmeans",
    maximum_iterations       = typemax(Int64),
    rng           = Random.GLOBAL_RNG
   )
   if typeof(mixtures) <: UnionAll
     mixtures = [mixtures() for i in 1:n_classes]
   end
   return GaussianMixtureRegressor(n_classes,initial_probmixtures,mixtures,tol,minimum_variance,minimum_covariance,initialisation_strategy,maximum_iterations,rng)
end

"""
$(TYPEDEF)

A non-linear regressor derived from fitting the data on a probabilistic model (Gaussian Mixture Model). Relatively fast but generally not very precise, except for data with a structure matching the chosen underlying mixture.

This is the multi-target version of the model. If you want to predict a single label (y), use the MLJ model [`GaussianMixtureRegressor`](@ref).

# Hyperparameters:
$(TYPEDFIELDS)

# Example:
```julia
julia> using MLJ

julia> X, y        = @load_boston;

julia> ydouble     = hcat(y, y .*2  .+5);

julia> modelType   = @load MultitargetGaussianMixtureRegressor pkg = "BetaML" verbosity=0
BetaML.GMM.MultitargetGaussianMixtureRegressor

julia> model       = modelType()
MultitargetGaussianMixtureRegressor(
  n_classes = 3, 
  initial_probmixtures = Float64[], 
  mixtures = BetaML.GMM.DiagonalGaussian{Float64}[BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing), BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing), BetaML.GMM.DiagonalGaussian{Float64}(nothing, nothing)], 
  tol = 1.0e-6, 
  minimum_variance = 0.05, 
  minimum_covariance = 0.0, 
  initialisation_strategy = "kmeans", 
  maximum_iterations = 9223372036854775807, 
  rng = Random._GLOBAL_RNG())

julia> mach        = machine(model, X, ydouble);

julia> fit!(mach);
[ Info: Training machine(MultitargetGaussianMixtureRegressor(n_classes = 3, …), …).
Iter. 1:        Var. of the post  20.46947926187522       Log-likelihood -23662.72770575145

julia> ŷdouble    = predict(mach, X)
506×2 Matrix{Float64}:
 23.3358  51.6717
 23.3358  51.6717
  ⋮       
 16.6843  38.3686
 16.6843  38.3686
```
"""
mutable struct MultitargetGaussianMixtureRegressor <: MMI.Deterministic
    "Number of mixtures (latent classes) to consider [def: 3]"
    n_classes::Int64 
    "Initial probabilities of the categorical distribution (n_classes x 1) [default: `[]`]"
    initial_probmixtures::Vector{Float64}
    """An array (of length `n_classes``) of the mixtures to employ (see the [`?GMM`](@ref GMM) module).
    Each mixture object can be provided with or without its parameters (e.g. mean and variance for the gaussian ones). Fully qualified mixtures are useful only if the `initialisation_strategy` parameter is  set to \"gived\"`
    This parameter can also be given symply in term of a _type_. In this case it is automatically extended to a vector of `n_classes`` mixtures of the specified type.
    Note that mixing of different mixture types is not currently supported.
    [def: `[DiagonalGaussian() for i in 1:n_classes]`]"""
    mixtures::Union{Type,Vector{<: AbstractMixture}}
    "Tolerance to stop the algorithm [default: 10^(-6)]"
    tol::Float64
    "Minimum variance for the mixtures [default: 0.05]"
    minimum_variance::Float64
    "Minimum covariance for the mixtures with full covariance matrix [default: 0]. This should be set different than minimum_variance (see notes)."
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
    "Maximum number of iterations [def: `typemax(Int64)`, i.e. ∞]"
    maximum_iterations::Int64
    "Random Number Generator [deafult: `Random.GLOBAL_RNG`]"
    rng::AbstractRNG
end
function MultitargetGaussianMixtureRegressor(;
    n_classes      = 3,
    initial_probmixtures  = [],
    mixtures      = [DiagonalGaussian() for i in 1:n_classes],
    tol           = 10^(-6),
    minimum_variance   = 0.05,
    minimum_covariance = 0.0,
    initialisation_strategy  = "kmeans",
    maximum_iterations       = typemax(Int64),
    rng           = Random.GLOBAL_RNG
) 
    if typeof(mixtures) <: UnionAll
        mixtures = [mixtures() for i in 1:n_classes]
    end
    return MultitargetGaussianMixtureRegressor(n_classes,initial_probmixtures,mixtures,tol,minimum_variance,minimum_covariance,initialisation_strategy,maximum_iterations,rng)
end

# ------------------------------------------------------------------------------
# Fit functions...

function MMI.fit(m::GaussianMixtureClusterer, verbosity, X)
    # X is nothing, y is the data: https://alan-turing-institute.github.io/MLJ.jl/dev/adding_models_for_general_use/#Models-that-learn-a-probability-distribution-1
    x          = MMI.matrix(X) # convert table to matrix
    #=
    if m.mixtures == :diag_gaussian
        mixtures = [DiagonalGaussian() for i in 1:m.n_classes]
    elseif m.mixtures == :full_gaussian
        mixtures = [FullGaussian() for i in 1:m.n_classes]
    elseif m.mixtures == :spherical_gaussian
        mixtures = [SphericalGaussian() for i in 1:m.n_classes]
    else
        error("Usupported mixture. Supported mixtures are either `:diag_gaussian`, `:full_gaussian` or `:spherical_gaussian`.")
    end
    =#
    typeof(verbosity) <: Integer || error("Verbosity must be a integer. Current \"steps\" are 0, 1, 2 and 3.")  
    verbosity = Utils.mljverbosity_to_betaml_verbosity(verbosity)
    mixtures = m.mixtures
    res        = gmm(x,m.n_classes,initial_probmixtures=deepcopy(m.initial_probmixtures),mixtures=mixtures, minimum_variance=m.minimum_variance, minimum_covariance=m.minimum_covariance,initialisation_strategy=m.initialisation_strategy,verbosity=verbosity,maximum_iterations=m.maximum_iterations,rng=m.rng)
    fitResults = (pₖ=res.pₖ,mixtures=res.mixtures) # res.pₙₖ
    cache      = nothing
    report     = (res.ϵ,res.lL,res.BIC,res.AIC)
    return (fitResults, cache, report)
end
MMI.fitted_params(model::GaussianMixtureClusterer, fitresult) = (weights=fitresult.pₖ, mixtures=fitresult.mixtures)

function MMI.fit(m::GaussianMixtureRegressor, verbosity, X, y)
    x  = MMI.matrix(X) # convert table to matrix
    typeof(verbosity) <: Integer || error("Verbosity must be a integer. Current \"steps\" are 0, 1, 2 and 3.")  
    verbosity = Utils.mljverbosity_to_betaml_verbosity(verbosity)
    ndims(y) < 2 || error("Trying to fit `GaussianMixtureRegressor` with a multidimensional target. Use `MultitargetGaussianMixtureRegressor` instead.")
    #=
    if typeof(y) <: AbstractMatrix
        y  = MMI.matrix(y)
    end
    
    if m.mixtures == :diag_gaussian
        mixtures = [DiagonalGaussian() for i in 1:m.n_classes]
    elseif m.mixtures == :full_gaussian
        mixtures = [FullGaussian() for i in 1:m.n_classes]
    elseif m.mixtures == :spherical_gaussian
        mixtures = [SphericalGaussian() for i in 1:m.n_classes]
    else
        error("Usupported mixture. Supported mixtures are either `:diag_gaussian`, `:full_gaussian` or `:spherical_gaussian`.")
    end
    =#
    mixtures = m.mixtures
    betamod = GMMRegressor2(
        n_classes     = m.n_classes,
        initial_probmixtures = m.initial_probmixtures,
        mixtures     = mixtures,
        tol          = m.tol,
        minimum_variance  = m.minimum_variance,
        initialisation_strategy = m.initialisation_strategy,
        maximum_iterations      = m.maximum_iterations,
        verbosity    = verbosity,
        rng          = m.rng
    )
    fit!(betamod,x,y)
    cache      = nothing
    return (betamod, cache, info(betamod))
end
function MMI.fit(m::MultitargetGaussianMixtureRegressor, verbosity, X, y)
    x  = MMI.matrix(X) # convert table to matrix
    typeof(verbosity) <: Integer || error("Verbosity must be a integer. Current \"steps\" are 0, 1, 2 and 3.")  
    verbosity = Utils.mljverbosity_to_betaml_verbosity(verbosity)
    ndims(y) >= 2 || @warn "Trying to fit `MultitargetGaussianMixtureRegressor` with a single-dimensional target. You may want to consider `GaussianMixtureRegressor` instead."
    #=
    if typeof(y) <: AbstractMatrix
        y  = MMI.matrix(y)
    end
    
    if m.mixtures == :diag_gaussian
        mixtures = [DiagonalGaussian() for i in 1:m.n_classes]
    elseif m.mixtures == :full_gaussian
        mixtures = [FullGaussian() for i in 1:m.n_classes]
    elseif m.mixtures == :spherical_gaussian
        mixtures = [SphericalGaussian() for i in 1:m.n_classes]
    else
        error("Usupported mixture. Supported mixtures are either `:diag_gaussian`, `:full_gaussian` or `:spherical_gaussian`.")
    end
    =#
    mixtures = m.mixtures
    betamod = GMMRegressor2(
        n_classes     = m.n_classes,
        initial_probmixtures = m.initial_probmixtures,
        mixtures     = mixtures,
        tol          = m.tol,
        minimum_variance  = m.minimum_variance,
        initialisation_strategy = m.initialisation_strategy,
        maximum_iterations      = m.maximum_iterations,
        verbosity    = verbosity,
        rng          = m.rng
    )
    fit!(betamod,x,y)
    cache      = nothing
    return (betamod, cache, info(betamod))
end


# ------------------------------------------------------------------------------
# Predict functions...

function MMI.predict(m::GaussianMixtureClusterer, fitResults, X)
    x               = MMI.matrix(X) # convert table to matrix
    (N,D)           = size(x)
    (pₖ,mixtures)   = (fitResults.pₖ, fitResults.mixtures)
    nCl             = length(pₖ)
    # Compute the probabilities that maximise the likelihood given existing mistures and a single iteration (i.e. doesn't update the mixtures)
    thisOut         = gmm(x,nCl,initial_probmixtures=pₖ,mixtures=mixtures,tol=m.tol,verbosity=NONE,minimum_variance=m.minimum_variance,minimum_covariance=m.minimum_covariance,initialisation_strategy="given",maximum_iterations=1,rng=m.rng)
    classes         = CategoricalArray(1:nCl)
    predictions     = MMI.UnivariateFinite(classes, thisOut.pₙₖ)
    return predictions
end

function MMI.predict(m::GaussianMixtureRegressor, fitResults, X)
    x               = MMI.matrix(X) # convert table to matrix
    betamod         = fitResults
    return dropdims(predict(betamod,x),dims=2)
end
function MMI.predict(m::MultitargetGaussianMixtureRegressor, fitResults, X)
    x               = MMI.matrix(X) # convert table to matrix
    betamod         = fitResults
    return predict(betamod,x)
end


# ------------------------------------------------------------------------------
# Model metadata for registration in MLJ...

MMI.metadata_model(GaussianMixtureClusterer,
    input_scitype    = MMI.Table(Union{MMI.Continuous,MMI.Missing}),
    output_scitype   = AbstractArray{<:MMI.Multiclass},       # scitype of the output of `transform`
    target_scitype   = AbstractArray{<:MMI.Multiclass},       # scitype of the output of `predict`
    #prediction_type  = :probabilistic,  # option not added to metadata_model function, need to do it separately
    supports_weights = false,                                 # does the model support sample weights?
	load_path        = "BetaML.GMM.GaussianMixtureClusterer"
)
MMI.prediction_type(::Type{<:GaussianMixtureClusterer}) = :probabilistic

MMI.metadata_model(GaussianMixtureRegressor,
    input_scitype    = MMI.Table(Union{MMI.Missing, MMI.Infinite}),
    target_scitype   = AbstractVector{<: MMI.Continuous},           # for a supervised model, what target?
    supports_weights = false,                                       # does the model support sample weights?
	load_path        = "BetaML.GMM.GaussianMixtureRegressor"
)
MMI.metadata_model(MultitargetGaussianMixtureRegressor,
    input_scitype    = MMI.Table(Union{MMI.Missing, MMI.Infinite}),
    target_scitype   = AbstractMatrix{<: MMI.Continuous},           # for a supervised model, what target?
    supports_weights = false,                                       # does the model support sample weights?
	load_path        = "BetaML.GMM.MultitargetGaussianMixtureRegressor"
)
