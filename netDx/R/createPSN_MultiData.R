#' Wrapper to create custom input features (patient similarity networks)
#'
#' @param dataList (list) key is datatype (e.g. clinical, rna, etc.,), value is
#'  table or RangedData)
#' Note that unit names should be rownames of the data structure.
#' e.g If dataList$rna contains genes, rownames(dataList) = gene names
#' @param groupList (list) key is datatype; value is a list of unit groupings
#' for that datatype. e.g. If rna data will be grouped by pathways, then 
#' groupList$rna would have pathway names as keys, and member genes as units.
#' Each entry will be converted into a PSN.
#' @param netDir (char) path to directory where networks will be stored
#' @param filterSet (char) vector of networks to include
#' @param customFunc (function) custom user-function to create PSN. 
#' Must take dataList,groupList,netDir as parameters. Must
#' check if a given groupList is empty (no networks to create) before 
#' the makePSN call for it. This is to avoid trying to make nets for datatypes
#' that did not pass feature selection
#' @param ... other parameters to makePSN_NamedMatrix() or makePSN_RangedSets()
#' @return (char) vector of network names. Side effect of creating the nets
#' @examples see examples/NestedCV_MultiData.Rmd for example use.
#' @export
createPSN_MultiData <- function(dataList,groupList,netDir,filterSet=NULL,
			customFunc,...) {

if (missing(dataList)) stop("dataList must be supplied.\n")
if (missing(groupList)) stop("groupList must be supplied.\n")
if (missing(netDir)) stop("netDir must be supplied.\n")

if (file.exists(netDir)) unlink(netDir,recursive=TRUE)
dir.create(netDir)

if (!is.null(filterSet)) {
	if (length(filterSet)<1) 
		stop("filterSet is empty. It needs to have at least one net to proceed.")
}
if (missing(customFunc)) stop("customFunc must be suppled.\n")

# Filter for nets (potentially feature-selected ones)
if (!is.null(filterSet)) {
	cat("Filter set provided; only making nets for those provided here\n")
	groupList2 <- list()
	for (nm in names(groupList)) {
			idx <- which(names(groupList[[nm]]) %in% filterSet)
			cat(sprintf("\t%s: %i of %i nets left\n",nm,
				length(idx),length(groupList[[nm]])))
			if (length(idx)>0) {
					groupList2[[nm]] <- groupList[[nm]][idx]
			} 
	}	
groupList <- groupList2; rm(groupList2)
} 

# call user-defined function for making PSN
netList <- customFunc(dataList=dataList,groupList=groupList,netDir=netDir,...)

return(netList)
}

