% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_summary.R
\name{summary.variance_cube}
\alias{summary.variance_cube}
\title{Summarize data cubes}
\usage{
\method{summary}{variance_cube}(
  object,
  ...,
  tile = object$tile[[1]],
  only_stats = FALSE,
  sample_size = 1e+05
)
}
\arguments{
\item{object}{Object of class "probs_cube"}

\item{...}{Further specifications for \link{summary}.}

\item{tile}{Tile to be summarized}

\item{only_stats}{Show only the statistics? (TRUE/FALSE)}

\item{sample_size}{Number of sample used to build statistics}
}
\value{
A summary of a probability cube
}
\description{
This is a generic function. Parameters depend on the specific
type of input.
}
\note{
Please refer to the sits documentation available in
<https://e-sensing.github.io/sitsbook/> for detailed examples.
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
