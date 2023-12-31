% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read_data.R
\name{load_GT_vcf}
\alias{load_GT_vcf}
\title{Load genotype VCF into numeric values: 0, 1, or 2}
\usage{
load_GT_vcf(vcf_file, rowname_format = "full", na.rm = TRUE, keep_GP = TRUE)
}
\arguments{
\item{vcf_file}{character(1), path to VCF file for donor genotypes}

\item{rowname_format}{the format of rowname: NULL is the default from vcfR,
short is CHROM_POS, and full is CHROM_POS_REF_ALT}

\item{na.rm}{logical(1), if TRUE, remove the variants with NA values}

\item{keep_GP}{logical(1), if TRUE, check if GP (genotype probability) exists
it will be returned}
}
\value{
A list representing the loaded genotype information with two
  components: GT, the usual numeric representation of genotype and GP the
  genotype probabilities. Note that if \code{keep_GP} is false the GP
  component will be NULL.
}
\description{
Note, the genotype VCF can be very big for whole genome. It would be more
efficient to only keep the wanted variants and samples. bcftools does such
jobs nicely.
}
\examples{
vcf_file <- system.file("extdata", "cellSNP.cells.vcf.gz",
    package = "cardelino"
)
GT_dat <- load_GT_vcf(vcf_file, na.rm = FALSE)
}
