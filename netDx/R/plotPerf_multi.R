#' Plots a set of ROC/PR curves with average.
#'
#' @details Plots average curves with individual curves imposed.
#' @param inList (list) ROCR::performance objects, one per iteration
#' @param plotType (char) one of ROC | PR | custom. Affects x/y labels
#' @param xlab (char) x-axis label
#' @param ylab (char) y-axis label
#' @param meanCol (char) colour for mean trendline
#' @return No value. Side effect of plotting ROC and PR curves
#' @examples
#' inDir <- sprintf("%s/extdata/KIRC_output", path.package("netDx.examples"))
#' all_rng <- list.files(path = inDir, pattern = "rng.")
#' fList <- sprintf("%s/%s/predictionResults.txt", inDir,all_rng)
#' dat <- read.delim(fList[1],sep="\t",h=T,as.is=T)
#' predClasses <- c('SURVIVEYES', 'SURVIVENO')
#' pred_col1 <- sprintf("%s_SCORE",predClasses[1])
#' pred_col2 <- sprintf("%s_SCORE",predClasses[2])
#' idx1 <- which(colnames(dat) == pred_col1)
#' idx2 <- which(colnames(dat) == pred_col2)
#' pred <- ROCR::prediction(dat[,idx1]-dat[,idx2], dat$STATUS==predClasses[1])
#' curRoc <- ROCR::performance(pred,"tpr","fpr")
#' plotPerf_multi(list(curRoc=curRoc),"ROC")
#' @export
plotPerf_multi <- function(inList,plotTitle="performance",
		plotType="ROC", xlab="TPR",ylab="FPR",meanCol="darkblue",
		xlim=c(0,1),ylim=c(0,1)){

	if (plotType=="ROC") {
		xlab <- "TPR"; ylab <- "FPR"
	} else if (plotType=="PR") {
		xlab <- "Precision"; ylab <- "Recall"
	} else {
		cat("custom type plot\n")
	}

	plot(0,0,type='n',bty='n',las = 1,xlim=xlim,ylim=ylim,
		xlab=xlab,ylab=ylab,
		main=plotTitle,cex.axis=1.3)
	out <- list()

	is_empty <- 0
	for (k in 1:length(inList)) {
		if(length(slotNames(inList[[k]])) == 0)	{
			is_empty <- is_empty+1;
			next;
		}

	x <- inList[[k]]@x.values[[1]]
	y <- inList[[k]]@y.values[[1]]

	cur <-aggregate(y,by=list(xvals=x),FUN=mean,na.rm=T)
	colnames(cur)<-c("x","y")
	out[[k]]<-cur

	points(x,y,type="l",col="gray90", lwd=3)
}

	# plot average trendline
	x <- inList[[k]]@x.values[[1]]
	y <- inList[[k]]@y.values[[1]]
	cur_y <- aggregate(y, by=list(xvals=x),FUN=mean,na.rm=T)
	cur <- cbind(cur_y, k)
	colnames(cur) <- c("x","y","k")
	out[[k]] <- cur
		points(x,y,type="l",col=meanCol,lwd=4)

	text(0.8*xlim[2],0.1*ylim[2],sprintf("N=%i",length(inList)-is_empty),
		cex=1.3)

	if (plotType=="ROC") abline(0,1,col='red',lwd=3)
	else if (plotType=="PR") abline(h=0.5,col='red',lwd=3)
}
