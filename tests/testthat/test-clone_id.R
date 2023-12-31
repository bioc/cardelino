# Tests for clone_id methods
# library(cardelino); library(testthat); source("test-clone_id.R")

context("test clone ID")
data("example_donor")

test_that("binomial EM inference works as expected", {
    assignments_EM <- clone_id(A_clone, D_clone,
        Config = tree$Z,
        inference = "EM"
    )
    expect_is(assignments_EM, "list")
})


assignments <- clone_id(A_clone, D_clone,
    Config = tree$Z,
    min_iter = 200, max_iter = 500,
    relax_Config = TRUE, relabel = TRUE
)

test_that("default inference works as expected", {
    expect_is(assignments, "list")
})


context("test plotting")

test_that("heatmap for assignment probability works as expected", {
    fig1 <- prob_heatmap(assignments$prob)
    expect_is(fig1, "ggplot")
})

test_that("pheatmap for variants probability across cells works as expected", {
    fig2 <- vc_heatmap(assignments$prob_variant, assignments$prob, tree$Z)
    expect_is(fig2, "pheatmap")
})

context("test assessment.R")
test_that("assign_scores, multiPRC, binaryPRC work as expected", {
    I_sim <- (assignments$prob == rowMax(assignments$prob))
    res <- assign_scores(assignments$prob, I_sim)
    expect_is(res, "list")
})

test_that("binaryROC work as expected", {
    I_sim <- (assignments$prob == rowMax(assignments$prob))
    res <- binaryROC(assignments$prob[, 1], I_sim[, 1])
    expect_is(res, "list")
})
