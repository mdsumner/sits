
#---- ml_model ----

.ml_model <- function(ml_model) {
    if ("model" %in% ls(environment(ml_model))) {
        environment(ml_model)[["model"]]
    } else if ("torch_model" %in% ls(environment(ml_model))) {
        environment(ml_model)[["torch_model"]]
    } else {
        stop("cannot extract model object")
    }
}

.ml_stats_0 <- function(ml_model) {
    # Old stats variable
    environment(ml_model)[["stats"]]
}

.ml_stats <- function(ml_model) {
    # New stats variable
    environment(ml_model)[["ml_stats"]]
}

.ml_samples <- function(ml_model) {
    environment(ml_model)[["samples"]]
}

.ml_class <- function(ml_model) {
    class(ml_model)[[1]]
}

.ml_features_name <- function(ml_model) {
    # Get feature names from variable used in training
    names(environment(ml_model)[["train_samples"]])[-2:0]
}

.ml_bands <- function(ml_model) {
    .sits_bands(.ml_samples(ml_model))
}

.ml_labels <- function(ml_model) {
    .sits_labels(.ml_samples(ml_model))
}
