% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/evalPerfOverCutoffs.R
\name{evalPerfOverCutoffs}
\alias{evalPerfOverCutoffs}
\title{Evaluate model performance for various network cutoffs}
\usage{
evalPerfOverCutoffs(pheno, pdat, p_GR, unitSet_GR, predClass, netScores,
  unitSets, maxScore, outDir, numCores = 1L, ...)
}
\arguments{
\item{pheno}{(data.frame) patient metadata. Patient ID (ID), subtypes
(STATUS), and whether they should be part of query or not (TT_STATUS; 
patients with TT_STATUS=train will be part of GM query)}

\item{pdat}{(matrix) patient data to build networks from. Rows are 
patients, columns are unit measures}

\item{p_GR}{(GRanges) GRanges of patient CNVs. Has ID column in
metadata, containing patient IDs. If NULL, assumes there is no
patient-range type data}

\item{unitSet_GR}{(list) sets of GRanges to group CNVs (e.g.
could have one GRanges per pathway, corresponding to regions in that 
pathway}

\item{netScores}{(list) scores of individual networks for each patient
label. Key is patient label; value is data.frame with two columns, 
PATHWAY_NAME and SCORE. PATHWAY_NAME should match names in unitSets}

\item{unitSets}{(list) unit groupings, each of which will be converted to
its own patient similarity network.}

\item{maxScore}{(integer) maximum score achievable by a network}

\item{outDir}{(char) directory to store results in}

\item{numCores}{(integer) num cores for parallel processing}

\item{...}{params for makePSN_NamedMatrix}
}
\description{
Evaluate model performance for various network cutoffs
}
\details{
Currently only works when all data can be provided as a 
single matrix. Also currently works only for binary classification 
although extension to 3+-way classificaiton is likely straightforward.
}
