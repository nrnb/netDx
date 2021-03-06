
suppressMessages(require(netDx))
suppressMessages(require(netDx.examples))

phenoFile <- sprintf("%s/extdata/KIRC_pheno.rda",
	path.package("netDx.examples"))
lnames <- load(phenoFile)
head(pheno)

outDir <- paste(getwd(),"plots",sep="/")
if (!file.exists(outDir)) dir.create(outDir)

predClasses <- c("SURVIVEYES","SURVIVENO")
inDir <- sprintf("%s/extdata/KIRC_output",
	path.package("netDx.examples"))
featScores <- getFeatureScores(inDir,predClasses=c("SURVIVEYES","SURVIVENO"))

featSelNet <- lapply(featScores, function(x) {
	callFeatSel(x, fsCutoff=10, fsPctPass=0.7)
})
pathFile <- sprintf("%s/extdata/Human_160124_AllPathways.gmt",
           path.package("netDx.examples"))
pathwayList <- readPathways(pathFile)

xpr_genes <- sprintf("%s/extdata/EMap_input/genenames.txt",
      path.package("netDx.examples"))
xpr_genes <- read.delim(xpr_genes,h=FALSE,as.is=TRUE)[,1]

pathwayList <- lapply(pathwayList, function(x) x[which(x %in% xpr_genes)])
netInfoFile <- sprintf("%s/extdata/KIRC_output/inputNets.txt",
      path.package("netDx.examples"))
netInfo <- read.delim(netInfoFile,sep="\t",h=FALSE,as.is=TRUE)
colnames(netInfo) <- c("netType","netName")

EMap_input <- writeEMapInput_many(featScores,pathwayList,
      netInfo,outDir=outDir)

pngFiles <- list()
ctr <- 1
for (curGroup in names(EMap_input)[1:2]) {
	pngFiles[[curGroup]] <- plotEmap(gmtFile=EMap_input[[curGroup]][1], 
		                        nodeAttrFile=EMap_input[[curGroup]][2],
		                        netName=curGroup,outDir=outDir,
													  createStyle=(ctr==1))
	RCy3::setVisualStyle("EMapStyle",RCy3::getNetworkSuid())
	ctr <- ctr+1
}
