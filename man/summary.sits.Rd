% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_summary.R
\name{summary.sits}
\alias{summary.sits}
\title{Summarize sits}
\usage{
\method{summary}{sits}(object, ...)
}
\arguments{
\item{object}{Object of classes "sits".}

\item{...}{Further specifications for \link{summary}.}
}
\value{
A summary of the sits tibble.
}
\description{
This is a generic function. Parameters depend on the specific
type of input.
}
\note{
Please refer to the sits documentation available in
<https://e-sensing.github.io/sitsbook/> for detailed examples.
}
\examples{
if (sits_run_examples()) {
     summary(samples_modis_ndvi)
}

}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
