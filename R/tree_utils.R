#' Get a clonal tree from a configuration matrix
#'
#' @param Config variant x clone matrix of binary values. The clone-variant
#' configuration, which encodes the phylogenetic tree structure. This is the
#' output Z of Canopy
#' @param P a one-column numeric matrix encoding the (observed or estimated)
#' prevalence (or frequency) of each clone
#' @param strictness character(1), a character string defining the strictness of
#' the function if there are all-zero rows in the Config matrix. If \code{"lax"}
#' then the function silently drops all-zero rows and proceeds. If \code{"warn"}
#' then the function warns of dropping all-zero rows and proceeds. If
#' \code{"error"} then the function throws an error is all-zero rows are
#' detected.
#'
#' @return
#' An object of class "phylo" describing the tree structure. The output object
#' also contains an element "sna" defining the clustering of variants onto the
#' branches of the tree, and if \code{P} is non-null it also contains VAF
#' (variant allele frequency), CCF (cell clone fraction) and clone prevalence
#' values (computed from the supplied \code{P} argument).
#'
#' @details
#' Output tree may be nonsensical if the input \code{Config} matrix does not
#' define a coherent tree structure.
#'
#' @author Davis McCarthy
#'
#' @import utils
#' @export
#'
#' @examples
#' Configk3 <- matrix(c(
#'     rep(0, 15), rep(1, 8), rep(0, 7), rep(1, 5), rep(0, 3),
#'     rep(1, 7)
#' ), ncol = 3)
#' tree_k3 <- get_tree(Config = Configk3, P = matrix(rep(1 / 3, 3), ncol = 1))
#' plot_tree(tree_k3)
get_tree <- function(Config, P = NULL, strictness = "lax") {
    if (!is.null(P)) {
        if (ncol(P) != 1) {
            stop(
                "P must be a matrix with one column encoding clone ",
                "prevalence values"
            )
        }
    }
    all_zero_rows <- rowSums(Config) == 0
    strictness <- match.arg(strictness, c("lax", "warn", "error"))
    if (any(all_zero_rows)) {
        if (strictness == "error") {
            stop("Config matrix contains all-zero rows.")
        } else {
            if (strictness == "warn") {
                warning(
                    "Dropped ", sum(all_zero_rows),
                    " all-zero rows from Config matrix."
                )
            } else {
                message(
                    "Dropped ", sum(all_zero_rows),
                    " all-zero rows from Config matrix."
                )
            }
            Config <- Config[!all_zero_rows, ]
        }
    }
    k <- ncol(Config) # number of clones
    varnames <- rownames(Config)
    sna <- matrix(nrow = nrow(Config), ncol = 3)
    sna[, 1] <- seq_len(nrow(sna))
    rownames(sna) <- varnames
    colnames(sna) <- c("sna", "sna.st.node", "sna.ed.node")
    tip_label <- seq_len(k)
    tip_vals <- 2^seq_len(k)
    ## Need to determine number of internal nodes in the tree
    Config2 <- t(t(Config) * tip_vals)
    var_bin_vals <- rowSums(Config2)
    node_vals <- names(table(var_bin_vals))
    node_vals <- node_vals[!(node_vals %in% tip_vals)]
    node_num <- sum(!(node_vals %in% tip_vals))
    ## define a list with subsets of edge matrices
    ## start with root node (k+1), which always connects to tip 1 (base clone)
    if (node_num > 0.5) {
        node_def_list <- list()
        edge_list <- list()
        for (i in seq_len(k - 1)) {
            clone_combos <- utils::combn(2:k, (k - i), simplify = FALSE)
            for (j in seq_len(length(clone_combos))) {
                test_sum <- sum(tip_vals[clone_combos[[j]]])
                if (test_sum %in% node_vals) {
                    node_def_list[[
                    paste0("node", paste0(clone_combos[[j]]), collapse = "_")
                    ]] <-
                        clone_combos[[j]]
                }
            }
        }
        if (node_num != length(node_def_list)) {
            stop("Conflict in computed number of internal nodes.")
        }
        ## Sort out edges for the root node
        tip_nodes <- seq_len(k)
        root_to_tip <- tip_nodes[
            !(tip_nodes %in% unique(unlist(node_def_list)))
        ]
        edge_list[["root_node_tips"]] <- matrix(
            c(rep(k + 1, length(root_to_tip)), root_to_tip),
            nrow = length(root_to_tip)
        )
        el_counter <- 1
        for (i in seq_len(length(node_def_list))) {
            ## add edge from root to internal node if not already done
            if (i < 1.5) {
                el_counter <- el_counter + 1
                edge_list[[el_counter]] <- matrix(c(k + 1, k + 1 + i), nrow = 1)
                sna[var_bin_vals == sum(2^node_def_list[[i]]), 2] <- k + 1
                sna[var_bin_vals == sum(2^node_def_list[[i]]), 3] <- k + 1 + i
            } else {
                clones_in_this_node <- node_def_list[[i]]
                clones_in_prev_nodes <- unique(
                    unlist(node_def_list[seq_len(i - 1)])
                )
                if (!any(clones_in_this_node %in% clones_in_prev_nodes)) {
                    el_counter <- el_counter + 1
                    edge_list[[el_counter]] <- matrix(c(k + 1, k + 1 + i),
                        nrow = 1
                    )
                    sna[var_bin_vals == sum(2^node_def_list[[i]]), 2] <- k + 1
                    sna[var_bin_vals == sum(2^node_def_list[[i]]), 3] <-
                        k + 1 + i
                }
            }
            ## add edge from internal node to internal node
            ## if all of the clones for the node are present in the previous
            ## node in the tree (immediately above in the hierarchy), then add
            ## the edge check the size of previous nodes, and select the node
            ## that has minimum number of clones that is more than the number
            ## in this node
            if (i > 1.5) {
                prev_nodes <- seq_len(i - 1)
                prev_node_sizes <- vapply(
                    node_def_list[prev_nodes], length,
                    numeric(1)
                )
                prev_nodes <- prev_nodes[prev_node_sizes >
                    length(node_def_list[[i]])]
                min_prev_node_size <- min(prev_node_sizes[prev_nodes])
                prev_nodes <- prev_nodes[prev_node_sizes[prev_nodes] ==
                    min_prev_node_size]
                for (j in prev_nodes) {
                    if (all(node_def_list[[i]] %in% node_def_list[[j]])) {
                        el_counter <- el_counter + 1
                        edge_list[[el_counter]] <- matrix(
                            c(k + 1 + j, k + 1 + i),
                            nrow = 1
                        )
                        sna[var_bin_vals == sum(2^node_def_list[[i]]), 2] <-
                            k + 1 + j
                        sna[var_bin_vals == sum(2^node_def_list[[i]]), 3] <-
                            k + 1 + i
                    }
                }
            }
            ## add edge from internal node to tip
            ## (if clone not present in any subsequent nodes)
            if (node_num < 1.5) {
                ## if only one internal node, there are edges from this node to
                ## all tips
                node_to_tip <- tip_nodes[-1]
                el_counter <- el_counter + 1
                edge_list[[el_counter]] <- matrix(
                    c(rep(k + 1 + i, length(node_to_tip)), node_to_tip),
                    nrow = length(node_to_tip)
                )
                for (m in node_to_tip) {
                    sna[var_bin_vals == sum(2^m), 2] <- k + 1 + i
                    sna[var_bin_vals == sum(2^m), 3] <- m
                }
            } else {
                ## if more than one internal node, need to check if tips
                ## mentioned in this node appear in any subsequent nodes
                node_to_tip <- node_def_list[[i]]
                if (i < node_num) {
                    node_to_tip <- node_to_tip[
                        !(node_to_tip %in% 
                            unique(unlist(node_def_list[(i + 1):node_num])))
                    ]
                }
                ## else this is the last node; just connect edges from node to
                ## tips
                if (length(node_to_tip) > 0.5) {
                    el_counter <- el_counter + 1
                    edge_list[[el_counter]] <- matrix(
                        c(rep(k + 1 + i, length(node_to_tip)), node_to_tip),
                        nrow = length(node_to_tip)
                    )
                    for (m in node_to_tip) {
                        sna[var_bin_vals == sum(2^m), 2] <- k + 1 + i
                        sna[var_bin_vals == sum(2^m), 3] <- m
                    }
                }
            }
        }
    } else {
        edge_list <- list("root_node" = matrix(c(rep(k + 1, k), seq_len(k)),
            ncol = 2
        ))
        for (j in 2:k) {
            sna[var_bin_vals == 2^j, 2] <- k + 1
            sna[var_bin_vals == 2^j, 3] <- j
        }
    }
    # node_def_list
    edge_mat <- do.call(rbind, edge_list)
    tree_out <- list(
        edge = edge_mat, Nnode = node_num + 1,
        tip.label = tip_label
    )
    class(tree_out) <- "phylo"
    tree_out$Z <- Config
    if (!is.null(P)) {
        tree_out$P <- P
        tree_out$VAF <- tree_out$Z %*% tree_out$P / 2
        tree_out$CCF <- tree_out$Z %*% tree_out$P
    }
    tree_out$sna <- sna
    tree_out
}
