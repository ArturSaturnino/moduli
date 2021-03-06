% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gene_cluster_utils.R
\name{score_gene_clusters}
\alias{score_gene_clusters}
\title{Enriches gene clusters with laplacian scores}
\usage{
score_gene_clusters(moduli)
}
\arguments{
\item{moduli}{A moduli object with a graph in the \code{snn.graph} slot}
}
\value{
A moduli object with laplacian scores and the rank of the gene cluster 
laplacian score saved in \code{gene.clusters$laplacian.score} and \code{gene.clusters$rank}
slots, respectively. The rank goes from most localized (smallest laplacian score) to least
localized (largest laplacian score).
}
\description{
Computes for each gene cluster the graph laplacian score of the function that indicates the
presence of the gene cluster in the point, using the snn graph of the moduli.
}
\examples{
data("pbmc_small_moduli")
pbmc_small_moduli <- get_snn(pbmc_small_moduli, 4)
pbmc_small_moduli <- score_gene_clusters(pbmc_small_moduli)

}
