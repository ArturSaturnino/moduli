#' Runs UMAP on moduli space
#' 
#' Computes a 2-d UMAP representation of the moduli space using \link[uwot]{umap}.
#' 
#' @param moduli A moduli object
#' @param n_neighbors Size of local neighborhood of umap (see \link[uwot]{umap}), defaults to 15
#' @param ... Additional parameters passed to \link[uwot]{umap}
#' @param seed Random seed, default value is 123
#' 
#' @return A moduli object with a umap representation saved to the \code{moduli.umap} slot
#' 
#' @examples 
#' data("pbmc_small_moduli")
#' 
#' pbmc_small_moduli <- run_umap_moduli(pbmc_small_moduli)
#' 
#' @export
run_umap_moduli <- function(moduli, n_neighbors = 15, ..., seed = 123){
  set.seed(seed)
  moduli$moduli.umap <- uwot::umap(moduli$metric, n_neighbors = n_neighbors,
                                   n_components = 2, ...)
  return(moduli)
}


#' Interactive UMAP plot of moduli space
#' 
#' Plot UMAP of moduli space, coloring analysis clusters and marking given points.
#' 
#' @param moduli A moduli object with a umap representation of the moduli space
#' @param mark.points Integer vector with ids of points to mark with "x", all points are marked with a circle if NULL.
#' Default value is NULL
#' @param color.clusters Vector with ids of analysis clusters to be colored, can only color 12 clusters. If NULL
#' the first 12 analysis clusters are colored. Default value is NULL
#' @param color.cluster.groups Vector with ids of analysis cluster groups to be colored, can only color 12 cluster groups.
#' Only of color.clusters or color.cluster.groups can be not NULL. Deafult value is NULL.
#' @param title Title of plot, default value is "UMAP plot of moduli space"
#' 
#' @return A plotly visualization. Hover text contains metadata about points. If analysis clusters are
#' enriched, differentially expressed gene clusters are marked with an asterisk.
#' 
#' @examples 
#' data("pbmc_small_moduli")
#' 
#' # clustering analysis, this is not necessary by enriches the visualization
#' pbmc_small_moduli <- get_snn(pbmc_small_moduli, 4)
#' pbmc_small_moduli <- cluster_moduli_space(pbmc_small_moduli)
#' 
#' # plotting
#' pbmc_small_moduli <- run_umap_moduli(pbmc_small_moduli)
#' visualize_moduli_space(pbmc_small_moduli)
#' 
#' @export
visualize_moduli_space <- function(moduli, mark.points = NULL, color.clusters = NULL,
                                   color.cluster.groups = NULL,
                                   title = "UMAP plot of moduli space"){
  if(is.null(moduli$moduli.umap)){
    stop("Error: Use run_umap_moduli before plotting")
  }
  if(!is.null(color.clusters) && !is.null(color.cluster.groups)){
    stop("Error: Only of color.clusters or color.cluster.groups can be not NULL")
  }
  
  if(!is.null(moduli$analysis.clusters) &&  is.null(color.clusters) && is.null(color.cluster.groups)){
    color.clusters <- sort(moduli$analysis.clusters$id)
    if(length(color.clusters) > 12) color.clusters <- color.clusters[1:12]
  }
 
  if(!is.null(color.clusters) && length(color.clusters) > 12){
    warning("Only the first 12 elements of color.clusters will be colored")
    color.clusters <- color.clusters[1:12]
  }
  
  if(!is.null(color.cluster.groups) && length(color.cluster.groups) > 12){
    warning("Only the first 12 elements of color.cluster.groups will be colored")
    color.cluster.groups <- color.cluster.groups[1:12]
  }
  
  data = data.frame(
    UMAP_1 = moduli$moduli.umap[,1],
    UMAP_2 = moduli$moduli.umap[,2]
  )
  # setting up marcation factors
  if(!is.null(mark.points)){
    mark.legend <- c("marked", "unmarked")
    mark.factors <- ifelse(moduli$points$id %in% mark.points, mark.legend[1], mark.legend[2])
    data$mark.factors <- factor(mark.factors, levels = mark.legend)
  }
  
  # setting up color factors
  if(!is.null(moduli$analysis.clusters)){
    membership <- point_metadata(moduli)$analysis.cluster
  }
  if(!is.null(color.clusters)){
    partition.factors <- character(nrow(moduli$points))
    partition.factors[!(membership %in% color.clusters)] <- "others"
    for(p in color.clusters){
      partition.factors[membership == p] <- paste("analysis cluster", p)
    }
    data$partition <- factor(partition.factors,
                             levels = c(paste("analysis cluster", color.clusters), "others"))
  }
  if(!is.null(color.cluster.groups)){
    partition.factors <- character(nrow(moduli$points))
    clst.grps <- get_analysis_cluster_groups(moduli)
    for(cg in color.cluster.groups){
      clusters <- clst.grps$clusters[[cg]]
      partition.factors[membership %in% clusters] <- paste("cluster group", cg)
    }
    partition.factors[partition.factors == ""] <- "others"
    data$partition <- factor(partition.factors,
                             levels = c(paste("cluster group", color.cluster.groups), "others"))
  }
  
  
  # setting up hover text  
  gene.cluster.info <- sapply(moduli$points$clusters, function(pt) paste(sort(pt), collapse = " "))
  # marking differerentially expressed clusters with *
  if(!is.null(moduli$analysis.clusters$exp.gene.clusters)){
    for(i in 1:nrow(moduli$analysis.clusters)){
      members <- moduli$points$id %in% moduli$analysis.clusters$points[[i]]
      splt.labels <- strsplit(gene.cluster.info[members], split = " ")
      for(gcl in moduli$analysis.clusters$exp.gene.clusters[[i]]){
        exp <- paste0("^", gcl, "$")
        rep <- paste0(gcl,"*")
        splt.labels <- lapply(splt.labels, function(x) sub(exp, rep, x))
      }
      gene.cluster.info[members] <- sapply(splt.labels, paste, collapse = " ")
    }
  }
 
  txt <- paste0("point id: ", moduli$points$id)
  if(!is.null(mark.points)) txt <- paste0(txt, ifelse(data$mark.factors == mark.legend[1]," (x)", ""))
  txt <- paste0(txt,"<br>gene clusters: ", gene.cluster.info)
  if(!is.null(moduli$analysis.clusters)) txt <- paste0(txt,"<br>analysis cluster: ", membership)
  data$txt <- txt
  
  # colors
  if(length(color.clusters) + length(color.cluster.groups) >= 3){
    cols <- RColorBrewer::brewer.pal(n = length(color.clusters) + length(color.cluster.groups), name = "Paired")
    cols <- c(cols , "black")
  }
  if(length(color.clusters) + length(color.cluster.groups) == 2){
    cols <- c("red", "blue" , "black")
  }
  if(length(color.clusters) + length(color.cluster.groups) == 1){
    cols <- c("red", "black")
  }
  if(length(color.clusters) + length(color.cluster.groups) == 0){
    cols <- "black"
  }
  alpha <- 0.5
  
  if(is.null(mark.points) && is.null(moduli$analysis.clusters)){
    plt <- plotly::plot_ly(
      data = data,
      x = ~UMAP_1,
      y = ~UMAP_2,
      type = "scatter",
      mode = "markers",
      color = I(cols),
      marker = list(opacity = alpha),
      text = ~txt,
      hoverinfo = "text"
    )
  }
  
  if(!is.null(mark.points) && is.null(moduli$analysis.clusters)){
    marker <- list(
      size = ifelse(data$mark.factors == mark.legend[1], 12, 6),
      opacity = ifelse(data$mark.factors == mark.legend[1], 1, 0.25)
    )
    
    plt <- plotly::plot_ly(
      data = data,
      x = ~UMAP_1,
      y = ~UMAP_2,
      type = "scatter",
      mode = "markers",
      symbol = ~mark.factors,
      symbols = c("x", "o"),
      color = I(cols),
      marker = marker,
      text = ~txt,
      hoverinfo = "text"
    )
  }
  
  if(is.null(mark.points) && !is.null(moduli$analysis.clusters)){
    plt <- plotly::plot_ly(
      data = data,
      x = ~UMAP_1,
      y = ~UMAP_2,
      type = "scatter",
      mode = "markers",
      color = ~partition,
      colors = cols,
      marker = list(opacity = alpha),
      text = ~txt,
      hoverinfo = "text"
    )
  }
  
  if(!is.null(mark.points) && !is.null(moduli$analysis.clusters)){
    plt <- plotly::plot_ly(
      data = data,
      x = ~UMAP_1,
      y = ~UMAP_2,
      type = "scatter",
      mode = "markers",
      size = ifelse(data$mark.factors == mark.legend[1], 12, 6),
      color = ~partition,
      colors = cols,
      symbol = ~mark.factors,
      symbols = c("x", "o"),
      text = ~txt,
      hoverinfo = "text"
    )
  }
 
  plt <- plotly::layout(plt, title = title)
  return(plt)
}

#' Runs UMAP on gene space
#' 
#' Computes a 2-d UMAP representation of the gene space using \link[uwot]{umap}.
#' 
#' @param moduli A moduli object
#' @param metric Metric in gene space to use as a dist object, the object must have the names of the genes. If
#' NULL, the correlation metric based on the \code{"scale.data"} slot of \code{moduli$seurat[[moduli$assay]]}
#' will be used. Default value is NULL
#' @param n_neighbors Size of local neighborhood of umap (see \link[uwot]{umap}), defaults to 15
#' @param ... Additional parameters passed to \link[uwot]{umap}
#' @param seed Random seed, default value is 123
#' 
#' @return A moduli object with a umap representation saved to the \code{gene.umap} slot
#' 
#' @examples 
#' data("pbmc_small_moduli")
#' 
#' pbmc_small_moduli <- run_umap_genes(pbmc_small_moduli)
#' 
#' @export
run_umap_genes <- function(moduli, metric = NULL, n_neighbors = 15, ..., seed = 123){
  set.seed(seed)
  if(is.null(metric)){
    gene.exp <- t(FetchData(moduli$seurat[[moduli$assay]],
                            vars = unique(unlist(moduli$gene.clusters$genes)),
                            slot = "scale.data"))
    gene.names <- rownames(gene.exp)
    umap.coords <- uwot::umap(gene.exp, n_neighbors = n_neighbors, n_components = 2, 
                              metric = "correlation", ...)
  }else{
    gene.names <- rownames(as.matrix(metric))
    umap.coords <- uwot::umap(metric, n_neighbors = n_neighbors, n_components = 2, ...)
  }
  rownames(umap.coords) <- gene.names
  moduli$gene.umap <- umap.coords
  return(moduli)
}



#' Interactive UMAP plot of gene space
#' 
#' Plot UMAP of gene space, coloring gene clusters and marking given genes.
#' 
#' @param moduli A moduli object with a umap representation of gene space
#' @param color.clusters Vector with ids of gene clusters to be colored, can only color 12 clusters. If NULL
#' the first 12 gene clusters are colored. Default value is NULL
#' @param mark.genes Integer vector with names of genes to mark with "x", all points are marked with a circle if NULL.
#' Default value is NULL
#' @param ignore.case Whether to ignore case for genes given to mark.genes, default value is FALSE
#' @param n.terms Number of name terms to print. Only has an effect if gene clusters are annotated. Default value is 1.
#' @param title Title of plot, default value is "UMAP plot of gene space"
#' 
#' @return A plotly visualization. Hover text contains about genes and gene clusters.
#' 
#' @examples 
#' data("pbmc_small_moduli")
#' 
#' pbmc_small_moduli <- run_umap_genes(pbmc_small_moduli)
#' visualize_gene_space(pbmc_small_moduli)
#' 
#' @export
visualize_gene_space <- function(moduli, color.clusters = NULL, mark.genes = NULL,
                                 ignore.case = F, n.terms = 1, title = "UMAP plot of gene space"){
  if(is.null(moduli$gene.umap)){
    stop("Error: Use run_umap_gene before plotting")
  }

  if(is.null(color.clusters)){
    color.clusters <- sort(moduli$gene.clusters$id)
    if(length(color.clusters) > 12) color.clusters <- color.clusters[1:12]
  }
  if(!is.null(color.clusters) && length(color.clusters) > 12){
    warning("Only the first 12 elements of color.clusters will be colored")
    color.clusters <- color.clusters[1:12]
  }
  
  data = data.frame(
    UMAP_1 = moduli$gene.umap[,1],
    UMAP_2 = moduli$gene.umap[,2]
  )
  gene.names <- rownames(moduli$gene.umap)
  
  # marking points
  if(!is.null(mark.genes)){
    mark.legend <- c("marked", "unmarked")
    if(ignore.case){
      mark.factors <- ifelse(tolower(gene.names) %in% tolower(mark.genes),
                             mark.legend[1], mark.legend[2])
    } else {
      mark.factors <- ifelse(gene.names %in% mark.genes, mark.legend[1], mark.legend[2])
    }
    data$mark.factors <- factor(mark.factors, levels = mark.legend)
  }
  
  # setting up gene clusters
  membership <- integer(length(gene.names))
  for(i in 1:nrow(moduli$gene.clusters)){
    membership[gene.names %in% moduli$gene.clusters$genes[[i]]] <- moduli$gene.clusters$id[i]
  }
  partition.factors <- character(length(gene.names))
  partition.factors[!(membership %in% color.clusters)] <- "others"
  for(gcl in color.clusters){
    partition.factors[membership == gcl] <- paste("gene cluster", gcl)
  }
  data$partition <- factor(partition.factors, levels = c(paste("gene cluster", color.clusters), "others"))
  
  # setting up hover text
  
  txt <- gene.names
  if(!is.null(mark.genes)){
    txt <- paste0(txt, ifelse(data$mark.factors == mark.legend[1]," (x)", ""))
  }
  txt <- paste0(gene.names, "<br>gene cluster: ", membership)
  # add laplacian scores
  if(!is.null(moduli$gene.cluster$laplacian.score)){
    ls <- numeric(length(membership))
    lr <- integer(length(membership))
    for(i in 1:nrow(moduli$gene.clusters)){
      ls[membership == moduli$gene.clusters$id[i]] <- moduli$gene.cluster$laplacian.score[i]
      lr[membership == moduli$gene.clusters$id[i]] <- moduli$gene.cluster$rank[i]
    }
    txt <- paste0(txt, "<br>cluster laplacian score: ", signif(ls, 3), " (", lr, ")" )
  }
  # add top terms name
  if(!is.null(moduli$gene.cluster$term.names)){
    tn <- character(length(membership))
    for(i in 1:nrow(moduli$gene.clusters)){
      if(length(moduli$gene.cluster$term.names[[i]]) > 0){
        tn[membership == moduli$gene.clusters$id[i]] <- paste0(
          moduli$gene.cluster$term.names[[i]][1:n.terms],
          collapse = ",<br>-"
        )
      }
    }
    txt <- paste0(txt, "<br>cluster terms:<br>-", tn)
  }
  data$txt <- txt
  
  # colors
  if(length(color.clusters) >= 3){
    cols <- c(RColorBrewer::brewer.pal(n = max(length(color.clusters)), name = "Paired"), "black")
  }
  if(length(color.clusters) == 2){
    cols <- c("red", "blue" , "black")
  }
  if(length(color.clusters) == 1){
    cols <- c("red", "black")
  }
  if(length(color.clusters) == 0){
    cols <- I("black")
  }
  
  
  if(is.null(mark.genes)){
    plt <- plotly::plot_ly(
      data = data,
      x = ~UMAP_1,
      y = ~UMAP_2,
      type = "scatter",
      mode = "markers",
      marker = list(opacity = 0.5),
      color = ~partition,
      colors = cols,
      text = ~txt,
      hoverinfo = "text"
    )
  } else {
    plt <- plotly::plot_ly(
      data = data,
      x = ~UMAP_1,
      y = ~UMAP_2,
      type = "scatter",
      mode = "markers",
      size = ifelse(data$mark.factors == mark.legend[1], 12, 6),
      color = ~partition,
      colors = cols,
      symbol = ~mark.factors,
      symbols = c("x", "o"),
      text = ~txt,
      hoverinfo = "text"
    )
  }
  
  plt <- plotly::layout(plt, title = title)
  return(plt)
  
}

