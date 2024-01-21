"Part of [BetaML](https://github.com/sylvaticus/BetaML.jl). Licence is MIT."

# MLJ interface for hard clustering models

export KMeans, KMedoids

# ------------------------------------------------------------------------------
# Model Structure declarations..
"""
$(TYPEDEF)
    
The classical KMeans clustering algorithm, from the Beta Machine Learning Toolkit (BetaML).

# Parameters:
$(TYPEDFIELDS)

# Notes:
- data must be numerical
- online fitting (re-fitting with new data) is supported

# Example:
```julia
julia> using MLJ

julia> X, y        = @load_iris;

julia> modelType   = @load KMeans pkg = "BetaML" verbosity=0
BetaML.Clustering.KMeans

julia> model       = modelType()
KMeans(
  n_classes = 3, 
  dist = BetaML.Clustering.var"#34#36"(), 
  initialisation_strategy = "shuffle", 
  initial_representatives = nothing, 
  rng = Random._GLOBAL_RNG())

julia> mach        = machine(model, X);

julia> fit!(mach);
[ Info: Training machine(KMeans(n_classes = 3, …), …).

julia> classes_est = predict(mach, X);

julia> hcat(y,classes_est)
150×2 CategoricalArrays.CategoricalArray{Union{Int64, String},2,UInt32}:
 "setosa"     2
 "setosa"     2
 "setosa"     2
 ⋮            
 "virginica"  3
 "virginica"  3
 "virginica"  1
```
"""
mutable struct KMeans <: MMI.Unsupervised
    "Number of classes to discriminate the data [def: 3]"
    n_classes::Int64
    "Function to employ as distance. Default to the Euclidean distance. Can be one of the predefined distances (`l1_distance`, `l2_distance`, `l2squared_distance`),  `cosine_distance`), any user defined function accepting two vectors and returning a scalar or an anonymous function with the same characteristics. Attention that, contrary to `KMedoids`, the `KMeansClusterer` algorithm is not guaranteed to converge with other distances than the Euclidean one."
    dist::Function
    """
    The computation method of the vector of the initial representatives.
    One of the following:
    - "random": randomly in the X space
    - "grid": using a grid approach
    - "shuffle": selecting randomly within the available points [default]
    - "given": using a provided set of initial representatives provided in the `initial_representatives` parameter
    """
    initialisation_strategy::String
    "Provided (K x D) matrix of initial representatives (useful only with `initialisation_strategy=\"given\"`) [default: `nothing`]"
    initial_representatives::Union{Nothing,Matrix{Float64}}
    "Random Number Generator [deafult: `Random.GLOBAL_RNG`]"
    rng::AbstractRNG
end
KMeans(;
    n_classes               = 3,
    dist                    = dist=(x,y) -> norm(x-y),
    initialisation_strategy = "shuffle",
    initial_representatives           = nothing,
    rng          = Random.GLOBAL_RNG,
 ) = KMeans(n_classes,dist,initialisation_strategy,initial_representatives,rng)

"""
$(TYPEDEF)

# Parameters:
$(TYPEDFIELDS)

The K-medoids clustering algorithm with customisable distance function, from the Beta Machine Learning Toolkit (BetaML).

Similar to K-Means, but the "representatives" (the cetroids) are guaranteed to be one of the training points. The algorithm work with any arbitrary distance measure.

# Notes:
- data must be numerical
- online fitting (re-fitting with new data) is supported

# Example: 
```julia
julia> using MLJ

julia> X, y        = @load_iris;

julia> modelType   = @load KMedoids pkg = "BetaML" verbosity=0
BetaML.Clustering.KMedoids

julia> model       = modelType()
KMedoids(
  n_classes = 3, 
  dist = BetaML.Clustering.var"#39#41"(), 
  initialisation_strategy = "shuffle", 
  initial_representatives = nothing, 
  rng = Random._GLOBAL_RNG())

julia> mach        = machine(model, X);

julia> fit!(mach);
[ Info: Training machine(KMedoids(n_classes = 3, …), …).

julia> classes_est = predict(mach, X);

julia> hcat(y,classes_est)
150×2 CategoricalArrays.CategoricalArray{Union{Int64, String},2,UInt32}:
 "setosa"     3
 "setosa"     3
 "setosa"     3
 ⋮            
 "virginica"  1
 "virginica"  1
 "virginica"  2
```
"""
 mutable struct KMedoids <: MMI.Unsupervised
    "Number of classes to discriminate the data [def: 3]"
    n_classes::Int64
    "Function to employ as distance. Default to the Euclidean distance. Can be one of the predefined distances (`l1_distance`, `l2_distance`, `l2squared_distance`),  `cosine_distance`), any user defined function accepting two vectors and returning a scalar or an anonymous function with the same characteristics."
    dist::Function
    """
    The computation method of the vector of the initial representatives.
    One of the following:
    - "random": randomly in the X space
    - "grid": using a grid approach
    - "shuffle": selecting randomly within the available points [default]
    - "given": using a provided set of initial representatives provided in the `initial_representatives` parameter
    """
    initialisation_strategy::String
    "Provided (K x D) matrix of initial representatives (useful only with `initialisation_strategy=\"given\"`) [default: `nothing`]"
    initial_representatives::Union{Nothing,Matrix{Float64}}
    "Random Number Generator [deafult: `Random.GLOBAL_RNG`]"
    rng::AbstractRNG
 end
 KMedoids(;
    n_classes               = 3,
    dist                    = (x,y) -> norm(x-y),
    initialisation_strategy = "shuffle",
    initial_representatives = nothing,
    rng                     = Random.GLOBAL_RNG,
  ) = KMedoids(n_classes,dist,initialisation_strategy,initial_representatives,rng)

# ------------------------------------------------------------------------------
# Fit functions...
function MMI.fit(m::Union{KMeans,KMedoids}, verbosity, X)
    x  = MMI.matrix(X)                        # convert table to matrix
    # Using low level API here. We could switch to APIV2...
    typeof(verbosity) <: Integer || error("Verbosity must be a integer. Current \"steps\" are 0, 1, 2 and 3.")  
    verbosity = mljverbosity_to_betaml_verbosity(verbosity)
    if typeof(m) == KMeans
        (assignedClasses,representatives) = BetaML.Clustering.kmeans(x,m.n_classes,dist=m.dist,initialisation_strategy=m.initialisation_strategy,initial_representatives=m.initial_representatives,rng=m.rng,verbosity=verbosity)
    else
        (assignedClasses,representatives) = BetaML.Clustering.kmedoids(x,m.n_classes,dist=m.dist,initialisation_strategy=m.initialisation_strategy,initial_representatives=m.initial_representatives,rng=m.rng, verbosity=verbosity)
    end
    cache=nothing
    report=nothing
    return ((classes=assignedClasses,centers=representatives,distanceFunction=m.dist), cache, report)
end
MMI.fitted_params(model::Union{KMeans,KMedoids}, fitresult) = (centers=fitresult[2], cluster_labels=CategoricalArrays.categorical(fitresults[1]))

# ------------------------------------------------------------------------------
# Transform functions...

""" fit(m::KMeans, fitResults, X) - Given a fitted clustering model and some observations, return the distances to each centroids """
function MMI.transform(m::Union{KMeans,KMedoids}, fitResults, X)
    x     = MMI.matrix(X) # convert table to matrix
    (N,D) = size(x)
    nCl   = size(fitResults.centers,1)
    distances = Array{Float64,2}(undef,N,nCl)
    for n in 1:N
        for c in 1:nCl
            distances[n,c] = fitResults.distanceFunction(x[n,:],fitResults[2][c,:])
        end
    end
    return MMI.table(distances)
end

# ------------------------------------------------------------------------------
# Predict functions...

""" predict(m::KMeans, fitResults, X) - Given a fitted clustering model and some observations, predict the class of the observation"""
function MMI.predict(m::Union{KMeans,KMedoids}, fitResults, X)
    x               = MMI.matrix(X) # convert table to matrix
    (N,D)           = size(x)
    nCl             = size(fitResults.centers,1)
    distances       = MMI.matrix(MMI.transform(m, fitResults, X))
    mindist         = argmin(distances,dims=2)
    assignedClasses = [Tuple(mindist[n,1])[2]  for n in 1:N]
    return CategoricalArray(assignedClasses,levels=1:nCl)
end

# ------------------------------------------------------------------------------
# Model metadata for registration in MLJ...

MMI.metadata_model(KMeans,
    input_scitype    = MMI.Table(MMI.Continuous),         # scitype of the inputs
    output_scitype   = MMI.Table(MMI.Continuous),         # scitype of the output of `transform`
    target_scitype   = AbstractArray{<:MMI.Multiclass},   # scitype of the output of `predict`
    supports_weights = false,                             # does the model support sample weights?
	load_path        = "BetaML.Bmlj.KMeans"
)

MMI.metadata_model(KMedoids,
    input_scitype    = MMI.Table(MMI.Continuous),         # scitype of the inputs
    output_scitype   = MMI.Table(MMI.Continuous),         # scitype of the output of `transform`
    target_scitype   = AbstractArray{<:MMI.Multiclass},   # scitype of the output of `predict`
    supports_weights = false,                             # does the model support sample weights?
	load_path        = "BetaML.Bmlj.KMedoids"
)