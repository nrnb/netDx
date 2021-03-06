#' LumA binary classification with resampling.
#' uses wrapper subroutine in netDx to build predictor 
rm(list=ls())

# Change this to a local directory where you have write permission
outDir <- "~/tmp/TCGA_BRCA_geneXpr_resample_test" 

numCores 	<- 8L  	# num cores available for parallel processing
GMmemory 	<- 4L  	# java memory in Gb
trainProp	<- 0.67 # fraction of samples to use for training

require(netDx)
require(netDx.examples)
data(TCGA_BRCA)
ph <- pheno; rm(pheno)

sink(sprintf("%s/BreastCancer_GeneExprOnly.log",outDir),split=TRUE)
tryCatch({
	cat("Start time\n")
	print(Sys.time())

	pathFile <- sprintf("%s/extdata/Human_160124_AllPathways.gmt", 
 	   path.package("netDx.examples"))
	pathwayList <- readPathways(pathFile)

	### TODO Should be able to pass GM memory setting.
	out <- buildPredictor_resampling(pheno=ph,pdat=xpr,predClass="LumA",
		nFoldCV=10L, numResamples=3L,
		unitSets=pathwayList,numCores=8L,outDir=outDir,overwrite=TRUE,
		seed_trainTest=42L, seed_resampling=103L)
	save(out,file=sprintf("%s/FinalResults.Rdata",outDir))
}, error=function(ex) {
	print(ex)
}, finally={
	cat("Closing log.\n")
	print(Sys.time())
	sink(NULL)
})
