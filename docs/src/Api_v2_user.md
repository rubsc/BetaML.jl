# [BetaML Api v2](@id api_usage)

!!! note
    The API described below is the default one starting from BetaML v0.8.

The following API is designed to further simply the usage of the various ML models provided by BetaML introducing a common workflow. This is the _user_ documentation. Refer to the [developer documentation](@ref api_implementation) to learn how the API is implemented. 

## Supervised , unsupervised and transformed models

_Supervised_ refers to models designed to _learn_ a relation between some _features_ (often noted with X) and some _labels_ (often noted with Y) in order to predict the label of new data given the observed features alone. Perceptron, decision trees or neural networks are common examples.
_Unsupervised_ and _transformer_ models relate to models that learn a "structure" from the data itself (without any label attached from which to learn) and report either some new information using this learned structure (e.g. a cluster class) or directly process a transformation of the data itself, like `PCAEncoder` or missing imputers.
There is no difference in BetaML about these kind of models, aside that the fitting (aka _training_) function for the former takes both the features and the labels. In particular there isn't a separate `transform` function as in other frameworks, but any information we need to learn using the model, wheter a label or some transformation of the original data, is provided by the `predict` function. 

### Model constructor

The first step is to build the model constructor by passing (using keyword arguments) the agorithm hyperparameters and various options (cache results flag, debug levels, random number generators, ...):

```
mod = ModelName(par1=X,par2=Y,...)
```

Sometimes a parameter is itself another model, in such case we would have:

```
mod = ModelName(par1=OtherModel(a_par_of_OtherModel=X,...),par2=Y,...)
```

### Training of the model

The second step is to _fit_ (aka _train_) the model:
```
fit!(m,X,[Y])
```
where `Y` is present only for supervised models.

For online algorithms, i.e. models that support updating of the learned parameters with new data, `fit!` can be repeated as new data arrive, altought not all algorithms guarantee that training each record at the time is equivalent to train all the records at once. In some algorithms the "old training" could be used as initial conditions, without consideration if these has been achieved with hundread or millions of records, and the new data we use for training become much more important than the old one for the determination of the learned parameters.

### Prediction

Fitted models can be used to predict `y` (wheter the label, some desired new information or a transformation) given new `X`:

```
ŷ = predict(mod,X)
```

As a convenience, if the model has been trained while having the `cache` option set on `true` (by default) the `ŷ` of the last training is retained in the  model object and it can be retrieved simply with `predict(mod)`. Also in such case the `fit!` function returns `ŷ` instead of `nothing` effectively making it to behave like a _fit-and-transform_ function. 
The 3 expressions below are hence equivalent :

```
ŷ  = fit!(mod,xtrain)    # only with `cache=true` in the model constructor (default)
ŷ1 = predict(mod)        # only with `cache=true` in the model constructor (default)
ŷ2 = predict(mod,xtrain) 
```

### Other functions

Models can be resetted to lose the learned information with `reset!(mod)` and training information (other than the algorithm learned parameters, see below) can be retrieved with `info(mod)`.

Hyperparameters, options and learned parameters can be retrieved with the functions `hyperparameters`, `parameters` and `options` respectively. Note that they can be used also to set new values to the model as they return a reference to the required objects.

!!! note
    Which is the difference between the output of `info`, `parameters` and the `predict` function ?
    The `predict` function (and, when cache is used, the `fit!` one too) returns the main information required from the model.. the prediceted label for supervised models, the class assignment for clusters or the reprojected data for PCA.... `info` returns complementary information like the number of dimensions of the data or the number of data emploied for training. It doesn't include information that is necessary for the training itself, like the centroids in cluser analysis. These can be retrieved instead using `parameters` that include all and only the information required to compute `predict`. 

Some models allow an inverse transformation, that using the parameters learned at trainign time (e.g. the scale factors) perform an inverse tranformation of new data to the space of the training data (e.g. the unscaled space). Use `inverse_predict(mod,xnew)`.



