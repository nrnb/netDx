#' This is an example of advanced predictor design with netDx. It illustrates
#' 1) nested cross-validation predictor design
#' 2) creating nets with multiple similarity measures
#' 3) a function to compute mean normalized difference when a datasource has
#' 2-5 variables. See function normDiff2()
#'
#' Context
#' ----------------------
#' Predict binarized survival for kidney renal clear cell carcinoma (KIRC)
#' using 5 types of data (clinical, RNA, DNA methylation, proteomic, 
#' miRNA). 
#' Feature design:
#' 1) For each datatype create a single similarity network
#' 2) In addition, using just RNA data, create pathway-level networks.
#' 
#' Predictor design:
#' Uses nested cross validation. The outer loop splits data 100 times 
#' (numSplits variable) into
#' train and blind test. The inner loop first performs 10-fold cross validation
#' on the specific train, and classifies the test. 
#' Therefore the output is:
#' 1) 100 predictionResults.txt files, each with classification for the 100
#' test samples
#' 2) 100 sets of network scores, each out of 10. 
#' 
#' The rule can then be set to call networks that score consistently well
#' as being "feature selected". e.g. Networks that score 10/10 100% of the time
#'
#' Output: See Example 3 of outputs.md in the main folder of the github repo

# ----------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------

#' 10-fold CV predictor design 
rm(list=ls())
require(netDx)
require(netDx.examples)

numCores <- 8L  # parallel processing cores
GMmemory <- 4L  # memory in Gigabytes for each fold of cross-validation to use
trainProp <- 0.8	# % split for train/test
cutoff <- 9			# score for inner cross-validation fold that decides which
								# nets get used within a fold for classifying a test sample
numSplits <- 100

### CHANGE THIS to your ROOT FOLDER
rootDir <- "/mnt/data2/BaderLab"
inDir <- sprintf("%s/PanCancer_KIRC/input",rootDir)
outRoot <- sprintf("%s/PanCancer_KIRC/output",rootDir)

dt <- format(Sys.Date(),"%y%m%d")
megaDir <- sprintf("%s/AllPlusPathways_%s",outRoot,dt)

# ----------------------------------------------------------------
# helper functions
# takes average of normdiff of each row in x
normDiff2 <- function(x) {
	# normalized difference 
	# x is vector of values, one per patient (e.g. ages)
	normDiff <- function(x) {
	    #if (nrow(x)>=1) x <- x[1,]
	    nm <- colnames(x)
	    x <- as.numeric(x)
	    n <- length(x)
	    rngX  <- max(x,na.rm=T)-min(x,na.rm=T)
	    
	    out <- matrix(NA,nrow=n,ncol=n);
	    # weight between i and j is
	    # wt(i,j) = 1 - (abs(x[i]-x[j])/(max(x)-min(x)))
	    for (j in 1:n) out[,j] <- 1-(abs((x-x[j])/rngX))
	    rownames(out) <- nm; colnames(out)<- nm
	    out
	}

	sim <- matrix(0,nrow=ncol(x),ncol=ncol(x))
	for (k in 1:nrow(x)) {
		tmp <- normDiff(x[k,,drop=FALSE])
		sim <- sim + tmp
		rownames(sim) <- rownames(tmp)
		colnames(sim) <- colnames(tmp)
	}
	sim <- sim/nrow(x)
	sim
}

# -----------------------------------------------------------
# Process input
# -----------------------------------------------------------
inFiles <- list(
	clinical=sprintf("%s/KIRC_clinical_core.txt",inDir),
	survival=sprintf("%s/KIRC_binary_survival.txt",inDir)
	)
datFiles <- list(
	rna=sprintf("%s/KIRC_mRNA_core.txt",inDir),
	prot=sprintf("%s/KIRC_RPPA_core.txt",inDir),
	mir=sprintf("%s/KIRC_miRNA_core.txt",inDir),
	dnam=sprintf("%s/KIRC_methylation_core.txt",inDir),
	cnv=sprintf("%s/KIRC_CNV_core.txt",inDir)
)

pheno <- read.delim(inFiles$clinical,sep="\t",h=T,as.is=T)
colnames(pheno)[1] <- "ID"

#======transform clinical data=========
pheno$grade <- as.vector(pheno$grade)
pheno$grade[pheno$grade=="G1"] <- "G2"
pheno$grade[pheno$grade=="GX"] <- "G2"
pheno$grade <- as.factor(pheno$grade)
pheno <- pheno[, -which(colnames(pheno)=="gender")]
#======================================

surv <- read.delim(inFiles$survival,sep="\t",h=T,as.is=T)
colnames(surv)[1:2] <- c("ID","STATUS_INT")
survStr <- rep(NA,nrow(surv))
survStr[surv$STATUS_INT<1] <- "SURVIVENO"
survStr[surv$STATUS_INT>0] <- "SURVIVEYES"
surv$STATUS <- survStr
pheno <- merge(x=pheno,y=surv,by="ID")
pheno$X <- NULL
# pheno$gender <- ifelse(pheno$gender=="FEMALE",1, 0)
pheno_nosurv <- pheno[1:4]

cat("Collecting patient data:\n")
dats <- list() #input data in different slots
cat("\t* Clinical\n")
clinical <- pheno_nosurv
rownames(clinical) <- clinical[,1];
clinical$grade <- as.numeric(factor(clinical$grade))
clinical$stage <- as.numeric(factor(clinical$stage))
clinical$ID <- NULL
clinical <- t(clinical)
dats$clinical <- clinical; rm(clinical)

# create master input net
for (nm in names(datFiles)) {
	cat(sprintf("\t* %s\n",nm))
	tmp <- read.delim(datFiles[[nm]],sep="\t",h=T,as.is=T)
	if (colnames(tmp)[ncol(tmp)]=="X") tmp <- tmp[,-ncol(tmp)]
	rownames(tmp) <- tmp[,1]
	tmp <- t(tmp[,-1])
	class(tmp) <- "numeric"
	dats[[nm]] <- tmp
}

cat("\t Ordering column names\n")
# include only data for patients in classifier
dats <- lapply(dats, function(x) { x[,which(colnames(x)%in%pheno$ID)]})
dats <- lapply(dats, function(x) { 
	midx <- match(pheno$ID,colnames(x))
	x <- x[,midx]
	x
})

# confirm patient order the same for all input nets
pname <- colnames(dats[[1]])
for (k in 2:length(dats)) {
	if (all.equal(colnames(dats[[k]]),pname)!=TRUE) {
		cat(sprintf("Patient order doesn't match for %s\n",
			names(dats)[k]))
		browser()
	} 
}

# input nets for each category
netSets <- lapply(dats, function(x) rownames(x)) 

# compile data
alldat <- do.call("rbind",dats)
pheno_all <- pheno

combList <- list(    
    clinical="clinical_cont",    
	mir="mir.profile",
	rna="rna.profile",
	prot="prot.profile",
	cnv="cnv.profile",
	dnam="dnam.profile",
    clinicalArna=c("clinical_cont","rna.profile"),    
    clinicalAmir=c("clinical_cont","mir.profile"),    
    clinicalAprot=c("clinical_cont","prot.profile"),    
    clinicalAdnam=c("clinical_cont","dnam.profile"),    
    clinicalAcnv=c("clinical_cont","cnv.profile"),    
    all="all")  

# now add pathways
pathFile <- sprintf("%s/extdata/Human_160124_AllPathways.gmt",
   path.package("netDx.examples"))
pathwayList <- readPathways(pathFile)

rm(pheno,pheno_nosurv)

# ----------------------------------------------------------
# Build classifier
# ----------------------------------------------------------
if (file.exists(megaDir)) unlink(megaDir,recursive=TRUE)
dir.create(megaDir)

logFile <- sprintf("%s/log.txt",megaDir)
sink(logFile,split=TRUE)
tryCatch({
## Create the mega database with all patients and all nets.
## This will be used to predict test samples by subsetting just for feature
## selected nets in a given round
## Note that this is useful for all train/test splits because we can always
## change which samples are query and can always subset based on which nets
## are feature selected in a given round.
netDir <- sprintf("%s/networks",megaDir)
nonclin <- setdiff(names(netSets),"clinical")

# Here we make three calls to makePSN_NamedMatrix.
# 1) Pearson corr (writeProfiles=TRUE) for non-clinical data
# 2) normDiff2 (writeProfiles=FALSE) for other types of data
# 3) Pearson corr (writeProfiles=TRUE) for pathway data
# Note
# 1) append=TRUE for second and third. 
# 2) when classifying test you need to repeat the exercise of creating
# three types of input networks, depending on whether networks from each
# class scored well.

netList <- makePSN_NamedMatrix(alldat,
	rownames(alldat),netSets[nonclin],netDir,
	verbose=FALSE,numCores=numCores,writeProfiles=TRUE)

# notice append=TRUE
netList2 <- makePSN_NamedMatrix(alldat, 
	rownames(alldat),netSets["clinical"],
	netDir,simMetric="custom",customFunc=normDiff2,
	verbose=FALSE,numCores=numCores,
	sparsify=TRUE,append=TRUE)

# group by pathway
netList3 <- makePSN_NamedMatrix(dats_train$rna, rownames(dats_train$rna),
 pathwayList,netDir,verbose=FALSE,
  numCores=numCores,writeProfiles=TRUE,append=TRUE)
cat(sprintf("Made %i RNA pathway nets\n", length(netList)))

netList <- c(netList,netList2,netList3)
cat(sprintf("Total of %i nets\n", length(netList)))
	
# now create database
megadbDir	<- GM_createDB(netDir, pheno_all$ID, megaDir,numCores=numCores)

# -------------------------------------------------------
# Outer loop of nested CV: Different train/test splits
# -------------------------------------------------------
for (rngNum in 1:numSplits) {

	rng_t0 <- Sys.time()
	cat(sprintf("-------------------------------\n"))
	cat(sprintf("RNG seed = %i\n", rngNum))
	cat(sprintf("-------------------------------\n"))
	outDir <- sprintf("%s/rng%i",megaDir,rngNum)
	dir.create(outDir)

	pheno_all$TT_STATUS <- splitTestTrain(pheno_all,pctT=trainProp,
											  setSeed=rngNum*5)
	write.table(pheno_all,file=sprintf("%s/tt_split.txt",outDir),sep="\t",
		col=T,row=F,quote=F)

	# --------------------------------------------
	# feature selection - train only
	pheno <- subset(pheno_all, TT_STATUS %in% "TRAIN")
	alldat_train <- alldat[,which(colnames(alldat) %in% pheno$ID)]
	
	netDir <- sprintf("%s/networks",outDir)
	nonclin <- setdiff(names(netSets),"clinical")

	# Here we limit ourselves to making nets with training samples
	netList <- makePSN_NamedMatrix(alldat_train, 
		rownames(alldat_train),netSets[nonclin],
		netDir,verbose=FALSE,numCores=numCores,
		writeProfiles=TRUE)
	netList2 <- makePSN_NamedMatrix(alldat_train, 
		rownames(alldat_train),netSets["clinical"],
		netDir,simMetric="custom",customFunc=normDiff2,
		verbose=FALSE,numCores=numCores,
		sparsify=TRUE,append=TRUE)
	netList <- c(netList,netList2)
	cat(sprintf("Total of %i nets\n", length(netList)))

	# now create database
	dbDir	<- GM_createDB(netDir, pheno$ID, outDir,numCores=numCores)

 # Ignore this loop -- it's example-specific and you will likely not need
 # this. It is only to see the effect of starting with different combinations
 # of input data
 	for (cur in  names(combList)) {
		t0 <- Sys.time()
	    cat(sprintf("%s\n",cur))
	    pDir <- sprintf("%s/%s",outDir, cur)
	    dir.create(pDir)
	
		# run featsel once per subtype
		subtypes <- unique(pheno$STATUS)

		# -------------------------------------------------------
		# Inner loop of nested CV: 10-fold CV
		# -------------------------------------------------------
		for (g in subtypes) {
		    pDir2 <- sprintf("%s/%s",pDir,g)
		    if (file.exists(pDir2)) unlink(pDir2,recursive=TRUE)
			dir.create(pDir2)
		
			cat(sprintf("\n******\nSubtype %s\n",g))
			pheno_subtype <- pheno
			## label patients not in the current class as residual
			nong <- which(!pheno_subtype$STATUS %in% g)
			pheno_subtype$STATUS[nong] <- "nonpred"
			## sanity check
			print(table(pheno_subtype$STATUS,useNA="always"))
			resDir    <- sprintf("%s/GM_results",pDir2)
			## query for feature selection comprises of training 
			## samples from the class of interest
			trainPred <- pheno_subtype$ID[
				which(pheno_subtype$STATUS %in% g)]
			
			# Cross validation
			GM_runCV_featureSet(trainPred, resDir, dbDir$dbDir, 
				nrow(pheno_subtype),incNets=combList[[cur]],
				verbose=T, numCores=numCores,
				GMmemory=GMmemory)
		
			# patient similarity ranks
			prank <- dir(path=resDir,pattern="PRANK$")
			# network ranks
			nrank <- dir(path=resDir,pattern="NRANK$")
			cat(sprintf("Got %i prank files\n",length(prank)))
				
		    # Compute network score
			pTally		<- GM_networkTally(paste(resDir,nrank,sep="/"))
			head(pTally)
			# write to file
			tallyFile	<- sprintf("%s/%s_pathway_CV_score.txt",resDir,g)
			write.table(pTally,file=tallyFile,sep="\t",col=T,row=F,quote=F)
		}

		predRes <- list()
		for (g in subtypes) {
			pDir2 <- sprintf("%s/%s",pDir,g)
			# get feature selected net names
			pTally <- read.delim(
				sprintf("%s/GM_results/%s_pathway_CV_score.txt",pDir2,g),
				sep="\t",h=T,as.is=T)

			# feature selected nets pass cutoff threshold
			pTally <- pTally[which(pTally[,2]>=cutoff),1]
			cat(sprintf("%s: %i pathways\n",g,length(pTally)))

			# query of all training samples for this class
			qSamps <- pheno_all$ID[which(pheno_all$STATUS %in% g & 
									 pheno_all$TT_STATUS%in%"TRAIN")]
		
			qFile <- sprintf("%s/%s_query",pDir2,g)
			GM_writeQueryFile(qSamps,incNets=pTally,nrow(pheno_all),qFile)
			resFile <- runGeneMANIA(megadbDir$dbDir,qFile,resDir=pDir2)
			predRes[[g]] <- GM_getQueryROC(sprintf("%s.PRANK",resFile),
				pheno_all,g)
		}

		# -------------------------------------------------------
		# Predict blind test for the current split
		# -------------------------------------------------------		
		predClass <- GM_OneVAll_getClass(predRes)
		out <- merge(x=pheno_all,y=predClass,by="ID")
		outFile <- sprintf("%s/predictionResults.txt",pDir)
		write.table(out,file=outFile,sep="\t",col=T,row=F,quote=F)
		
		acc <- sum(out$STATUS==out$PRED_CLASS)/nrow(out)
		cat(sprintf("Accuracy on %i blind test subjects = %2.1f%%\n",
			nrow(out), acc*100))
		
		require(ROCR)
		ROCR_pred <- prediction(out$SURVIVEYES_SCORE-out$SURVIVENO,
							out$STATUS=="SURVIVEYES")
		save(predRes,ROCR_pred,file=sprintf("%s/predRes.Rdata",pDir))
		}
        
    #cleanup to save disk space
    system(sprintf("rm -r %s/dataset %s/tmp %s/networks", 
        outDir,outDir,outDir))
    system(sprintf("rm -r %s/dataset %s/networks", 
        outDir,outDir))

}
	pheno_all$TT_STATUS <- NA

	rng_t1 <- Sys.time()
	cat(sprintf("Time for one train/test split:"))
	print(rng_t1-rng_t0)

}, error=function(ex){
	print(ex)
}, finally={
	sink(NULL)
})
