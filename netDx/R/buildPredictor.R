#' Run nested cross-validation on data 
#' 
#' @details wrapper function to run netDx with nested cross-validation, 
#' with an inner loop of X-fold cross-validation and an outer loop of different
#' random splits of data into train and blind test. The user needs to supply
#' a custom function to create PSN, see createPSN_MultiData(). This wrapper
#' provides flexibility for designs with one or several heterogeneous data
#' types, and one or more ways of defining patient similarity. 
#' For example, designs it handles includes
#' 1) Single datatype, single similarity metric: Expression data -> pathways
#' 2) Single datatype, multiple metrics: Expression data -> pathways
#'	(Pearson corr) and single gene networks (normalized difference)
#' 3) Multiple datatypes, multiple metrics: Expression -> Pathways; 
#'	Clinical -> single or grouped nets
#' @param pheno (data.frame) sample metadata, must have ID and STATUS columns
#' @param dataList (list) keys are datatypes; values contain patient data
#' for the corresponding datatype. e.g. dataList[["rna"]] contains expression
#' matrix. Rows are units (e.g. genes, individual clinical variables) and 
#' columns are patients
#' @param groupList (list) keys are datatypes and values are lists indicating
#' how units for those datatypes are to be grouped. Keys must match those 
#' in dataList. Each entry of groupList[[k]] will generate a new PSN.
#'  e.g. groupList[["rna"]] could be a list of pathway definitions. 
#' So keys(groupList[["rna"]]) would have pathway names, generating one PSN
#' per pathways, and values(groupList[["rna"]]) would be genes that would be
#' grouped for the corresponding pathwayList.
#' @param makeNetFunc (function) user-defined function for creating the set
#' of input PSN provided to netDx. See createPSN_MultiData()::customFunc.
#' @param outDir (char) directory where results will be stored. If this 
#' directory exists, its contents will be overwritten
#' @param trainProp (numeric 0 to 1) Percent samples to use for training
#' @param featScoreMax (integer) number of CV folds in inner loop
#' @param numSplits (integer) number of train/blind test splits (i.e. iterations
#' of outer loop)
#' @param numCores (integer) number of CPU cores for parallel processing
#' @param JavaMemory (integer) memory in (Gb) used for each fold of CV
#' @param featSelCutoff (integer) cutoff for inner-fold CV to call feature-selected
#' in a given split
#' @param keepAllData (logical) if TRUE keeps all intermediate files, even
#' those not needed for assessing the predictor. Use very cautiously as for
#' some designs, each split can result in using 1Gb of data.
#' @param startAt (integer) which of the splits to start at (e.g. if the
#' job aborted part-way through)
#' @param preFilter (logical) if TRUE uses lasso to prefilter dataList within 
#' cross-validation loop. Only variables that pass lasso get included. The
#' current option is not recommended for pathway-level features as most genes
#' will be eliminated by lasso. Future variations may allow other prefiltering
#' options that are more lenient.
#' @param impute (logical) if TRUE applies imputation by median within CV
#' @import glmnet
#' @export
buildPredictor <- function(pheno,dataList,groupList,outDir,makeNetFunc,
	featScoreMax=10L,trainProp=0.8,numSplits=10L,numCores,JavaMemory=4L,featSelCutoff=9L,
	keepAllData=FALSE,startAt=1L, preFilter=FALSE,impute=FALSE) { 


### tests# pheno$ID and $status must exist
if (missing(dataList)) stop("dataList must be supplied.\n")
if (missing(groupList)) stop("groupList must be supplied.\n")
if (trainProp <= 0 | trainProp >= 1) 
		stop("trainProp must be greater than 0 and less than 1")
if (startAt > numSplits) stop("startAt should be between 1 and numSplits")

megaDir <- outDir
if (file.exists(megaDir)) unlink(megaDir,recursive=TRUE)
dir.create(megaDir)

# set aside for testing within each split
pheno_all <- pheno; 

logFile <- sprintf("%s/log.txt",megaDir)
sink(logFile,split=TRUE)
cat("Predictor started at:\n")
print(Sys.time())
tryCatch({

# run featsel once per subtype
subtypes <- unique(pheno$STATUS)

cat(sprintf("-------------------------------\n"))
cat(sprintf("# patients = %i\n", nrow(pheno)))
cat(sprintf("# classes = %i { %s }\n", length(subtypes),
	paste(subtypes,collapse=",")))
cat("Sample breakdown by class\n")
print(table(pheno$STATUS))
cat(sprintf("Nested CV design = %i CV x %i splits\n", featScoreMax, numSplits))
cat(sprintf("Datapoints:\n"))
for (nm in names(dataList)) {
	cat(sprintf("\t%s: %i units\n", nm, nrow(dataList[[nm]])))
}

# create master list of possible networks
cat("# input nets provided:\n")
netFile <- sprintf("%s/inputNets.txt", megaDir)
cat("NetType\tNetName\n",file=netFile)
for (nm in names(groupList)) {
	curNames <- names(groupList[[nm]])
	for (nm2 in curNames) {
		cat(sprintf("%s\t%s\n",nm,nm2),file=netFile,append=TRUE)
	}
}


cat("\n\nCustom function to generate input nets:\n")
print(makeNetFunc)
cat(sprintf("-------------------------------\n\n"))

for (rngNum in startAt:numSplits) {
	cat(sprintf("-------------------------------\n"))
	cat(sprintf("RNG seed = %i\n", rngNum))
	cat(sprintf("-------------------------------\n"))
	outDir <- sprintf("%s/rng%i",megaDir,rngNum)
	dir.create(outDir)

	pheno_all$TT_STATUS <- splitTestTrain(pheno_all,pctT=trainProp,
											  setSeed=rngNum*5)
	pheno <- subset(pheno_all, TT_STATUS %in% "TRAIN")
	dats_train <- lapply(dataList,function(x) { 
						 x[,which(colnames(x) %in% pheno$ID)]})

	if (impute) {
	cat("**** IMPUTING ****\n")
	dats_train <- lapply(dats_train, function(x) {
		missidx <- which(rowSums(is.na(x))>0) 
		for (i in missidx) {
			na_idx <- which(is.na(x[i,]))
			x[i,na_idx] <- median(x[i,],na.rm=TRUE) 
		}
		x
	})
	}

	# prefilter with lasso
	if (preFilter) {
	set.seed(123)
	cat("Prefiltering enabled\n")
	for (nm in names(dats_train)) {
		cat(sprintf("%s: %i variables\n",nm,nrow(dats_train[[nm]])))
		if (nrow(dats_train[[nm]])<2)  # only has one var, take it.
			vars <- rownames(dats_train[[nm]])
		else { 
			newx <- na.omit(dats_train[[nm]])
			tmp <- pheno[which(pheno$ID %in% colnames(newx)),]
			tryCatch( {
			fit <- cv.glmnet(x=t(newx),
					y=factor(tmp$STATUS), family="binomial", alpha=1) # lasso
			}, error=function(ex) {
				print(ex)
				cat("*** You may need to set impute=TRUE for prefiltering ***\n")
			},finally={
			})
			wt <- abs(coef(fit,s="lambda.min")[,1])
			vars <- setdiff(names(wt)[which(wt>.Machine$double.eps)],
				"(Intercept)")
			}
		if (length(vars)>0) {
			tmp <- dats_train[[nm]]
			tmp <- tmp[which(rownames(tmp) %in% vars),,drop=FALSE]
			dats_train[[nm]] <- tmp
		} else {
			# leave dats_train as is, make a single net
		} 
		cat(sprintf("rngNum %i: %s: %s pruned\n",rngNum,nm,length(vars)))
		}
	}
	
	cat("# datapoints to make training nets\n")
	for (nm in names(dats_train)) {
		cat(sprintf("rngNum %i: %s: %i measures\n", 
			rngNum,nm,nrow(dats_train[[nm]])))
	}

	netDir <- sprintf("%s/networks",outDir)
	createPSN_MultiData(dataList=dats_train,groupList=groupList,
			netDir=netDir,customFunc=makeNetFunc,numCores=numCores)
	dbDir	<- compileFeatures(netDir, pheno$ID, outDir, numCores=numCores)
	

  # run cross-validation for each subtype
	for (g in subtypes) {
	    pDir <- sprintf("%s/%s",outDir,g)
	    if (file.exists(pDir)) unlink(pDir,recursive=TRUE);dir.create(pDir)
	
			cat(sprintf("\n******\nClass: %s\n",g))
			pheno_subtype <- pheno
			pheno_subtype$STATUS[which(!pheno_subtype$STATUS %in% g)] <- "nonpred"
			trainPred <- pheno_subtype$ID[which(pheno_subtype$STATUS %in% g)]
			print(table(pheno_subtype$STATUS,useNA="always"))
		
			# Cross validation
			resDir <- sprintf("%s/GM_results",pDir)
			runFeatureSelection(trainPred, 
				outDir=resDir, dbPath=dbDir$dbDir, 
				nrow(pheno_subtype),verbose=T, numCores=numCores,
				featScoreMax=featScoreMax,JavaMemory=JavaMemory)
	
	  	# Compute network score
			nrank <- dir(path=resDir,pattern="NRANK$")
			pTally		<- compileFeatureScores(paste(resDir,nrank,sep="/"))
			tallyFile	<- sprintf("%s/%s_pathway_CV_score.txt",resDir,g)
			write.table(pTally,file=tallyFile,sep="\t",col=T,row=F,quote=F)
	}
	
	## Class prediction for this split
	pheno <- pheno_all
	predRes <- list()
	for (g in subtypes) {
		pDir <- sprintf("%s/%s",outDir,g)
		pTally <- read.delim(
			sprintf("%s/GM_results/%s_pathway_CV_score.txt",pDir,g),
			sep="\t",h=T,as.is=T)
		idx <- which(pTally[,2]>=featSelCutoff)

		pTally <- pTally[idx,1]
		pTally <- sub(".profile","",pTally)
		pTally <- sub("_cont","",pTally)
		cat(sprintf("%s: %i networks\n",g,length(pTally)))
		netDir <- sprintf("%s/networks",pDir)

		dats_tmp <- list()
		for (nm in names(dataList)) {
			passed <- rownames(dats_train[[nm]])
			tmp <- dataList[[nm]]
			# only variables passing prefiltering should be used to make PSN
			dats_tmp[[nm]] <- tmp[which(rownames(tmp) %in% passed),] 
		}		

		# ------
		# Impute test samples if flag set
		# impute
		if (impute) {
		train_samp <- pheno_all$ID[which(pheno_all$TT_STATUS %in% "TRAIN")]
		test_samp <- pheno_all$ID[which(pheno_all$TT_STATUS %in% "TEST")]
		dats_tmp <- lapply(dats_tmp, function(x) {
			missidx <- which(rowSums(is.na(x))>0) 
			train_idx <- which(colnames(x) %in% train_samp)
			test_idx <- which(colnames(x) %in% test_samp)
			for (i in missidx) {
				# impute train and test separately
				na_idx <- intersect(which(is.na(x[i,])),train_idx)
				na_idx1 <- na_idx
				x[i,na_idx] <- median(x[i,train_idx],na.rm=TRUE) 
	
				na_idx <- intersect(which(is.na(x[i,])),test_idx)
				na_idx2 <- na_idx
				x[i,na_idx] <- median(x[i,test_idx],na.rm=TRUE) 
			}
			x
		})
		#alldat_tmp <- do.call("rbind",dats_tmp)
		}

		if (length(pTally)>=1) {
		createPSN_MultiData(dataList=dats_tmp,groupList=groupList,
			netDir=sprintf("%s/networks",pDir),
			customFunc=makeNetFunc,numCores=numCores,
			filterSet=pTally)
		dbDir <- compileFeatures(netDir,pheno$ID,pDir,numCores=numCores)

		# run query for this class
		qSamps <- pheno$ID[which(pheno$STATUS %in% g & pheno$TT_STATUS%in%"TRAIN")]
		qFile <- sprintf("%s/%s_query",pDir,g)
		writeQueryFile(qSamps,"all",nrow(pheno),qFile)
		resFile <- runQuery(dbDir$dbDir,qFile,resDir=pDir,
			JavaMemory=JavaMemory, numCores=numCores)
		predRes[[g]] <- getPatientRankings(sprintf("%s.PRANK",resFile),pheno,g)
		} else {
			predRes[[g]] <- NA
		}
	}
	
	if (sum(is.na(predRes))>0) {
		cat(sprintf("RNG %i : One or more classes have no selected features. Not classifying\n", rngNum))
	} else {
		predClass <- predictPatientLabels(predRes)
		out <- merge(x=pheno_all,y=predClass,by="ID")
		outFile <- sprintf("%s/predictionResults.txt",outDir)
		write.table(out,file=outFile,sep="\t",col=T,row=F,quote=F)
		
		acc <- sum(out$STATUS==out$PRED_CLASS)/nrow(out)
		cat(sprintf("Accuracy on %i blind test subjects = %2.1f%%\n",
			nrow(out), acc*100))
	}
        
	if (!keepAllData) {
    system(sprintf("rm -r %s/dataset %s/tmp %s/networks",                       
        outDir,outDir,outDir))                                                  
	for (g in subtypes) {
    system(sprintf("rm -r %s/%s/dataset %s/%s/networks",
        outDir,g,outDir,g))
	}
	}# endif !keepAllData
	}
}, error=function(ex){
	print(ex)
}, finally={
	cat("Predictor completed at:\n")
	print(Sys.time())
	sink(NULL)
})

}

