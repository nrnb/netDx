% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/writeEmapInput.R
\name{writeEMapInput}
\alias{writeEMapInput}
\title{write enrichment map for consensus nets}
\usage{
writeEMapInput(featScores, namedSets, netInfo, outPfx = "curr",
  pctPass = 0.7, minScore = 1, maxScore = 10,
  trimFromName = c(".profile", "_cont"), verbose = FALSE)
}
\arguments{
\item{featScores}{(data.frame) network scores across rounds of cross
validation. Rows are networks and columns are network name followed by
scores for cross-validation rounds. Output of getFeatureScores()}

\item{namedSets}{(list) list of nets and units (e.g.e pathway names and
genes). Should only contain units profiled in this dataset}

\item{netInfo}{(data.frame) Table of network name (netName) and type
(netType). Type is used to assign shapes to nodes:
 clinical                                          clinical
      rna GUANOSINE_NUCLEOTIDES__I_DE_NOVO__I__BIOSYNTHESIS
      rna                              RETINOL_BIOSYNTHESIS}

\item{pctPass}{(numeric between 0 and 1) fraction of iterations that
a net's score must pass consCutoff for, to be included in the consensus
map}

\item{minScore}{(integer) features with score below this cutoff are
excluded from downstream analyses}

\item{maxScore}{(integer) maximum possible score in one round of cross-
validation. e.g. for 10-fold cross-validation, maxScore=10.}

\item{trimFromName}{(char) strings to trim from name with sub()}

\item{verbose}{(logical) print messages}

\item{consCutoff}{(integer) nets must pass this cutoff in at least
pctPass of the iterations to be written to file}
}
\value{
1) <outPfx>.gmt file - for enrichment map
2) <outPfx>_nodeAttr.txt (file) table with node properties, notably type,
pctPass
}
\description{
write enrichment map for consensus nets
}
\examples{
inDir <- sprintf("\%s/extdata/KIRC_output", path.package("netDx.examples"))
outDir <- paste(getwd(),"plots",sep="/")
if (!file.exists(outDir)) dir.create(outDir)
featScores <- getFeatureScores(inDir,predClasses=c("SURVIVEYES","SURVIVENO"))
gp <- names(featScores)[1]
pathFile <- sprintf("\%s/extdata/Human_160124_AllPathways.gmt",
          path.package("netDx.examples"))
pathwayList <- readPathways(pathFile)
pathwayList <- pathwayList[c(1:5)]
netInfo <- read.delim(netInfoFile,sep="\\t",h=FALSE,as.is=TRUE)
output_files <- writeEMapInput(featScores[[gp]],pathwayList,netInfo,
                  outPfx=sprintf("\%s/\%s",outDir,gp))
}
