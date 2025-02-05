% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_summary.R
\name{summary.raster_cube}
\alias{summary.raster_cube}
\title{Summarize data cubes}
\usage{
\method{summary}{raster_cube}(
  object,
  ...,
  tile = object$tile[[1]],
  date = NULL,
  only_stats = FALSE,
  sample_size = 1e+05
)
}
\arguments{
\item{object}{Object of classes "raster_cube".}

\item{...}{Further specifications for \link{summary}.}

\item{tile}{Tile to be summarized}

\item{date}{Date to be summarized}

\item{only_stats}{Show only the statistics? (TRUE/FALSE)}

\item{sample_size}{Number of sample used to build statistics}
}
\value{
A summary of the data cube.
}
\description{
This is a generic function. Parameters depend on the specific
type of input.
}
\note{
Please refer to the sits documentation available in
<https://e-sensing.github.io/sitsbook/> for detailed examples.

if (sits_run_examples()) {
    # create a data cube from local files
    data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
    cube <- sits_cube(
        source = "BDC",
        collection = "MOD13Q1-6",
        data_dir = data_dir
    )
summary(cube)
}
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
