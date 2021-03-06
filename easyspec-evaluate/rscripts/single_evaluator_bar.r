args <- commandArgs(trailingOnly=TRUE)

if (length(args) != 9) {
  stop("Usage: single_evaluator_bar.r common.r input.csv output.pdf granularity group example funcname evaluator indication")
}

common <- args[1]
inFile <- args[2]
outPdf <- args[3]
# granularity <- args[4]
group <- args[5]
sourcefile <- args[6]
funcname <- args[7]
evaluator <- args[8]
indication <- args[9]

source(common)

res = read.csv(inFile, header=TRUE)
res <- res[res$focus == funcname,]
res <- res[res$evaluator == evaluator,]

# Make the output numeric
res$output <- suppressWarnings(as.numeric(as.character(res$output)))

# Replace NaN with '0'
res$output <- replace(res$output, is.na(res$output), 0)


if(length(res$output) != 0) {
  startPdf(outPdf)
  par(mar=c(3.5,0.41,0.41,0.21))

  # Extra large bottom margin
  barplot(
      res$output
    , names.arg=res$strategy
    , main = paste("Source:", sourcefile, ", ", "Focus:", funcname, ", ", "Evaluator:", evaluator, paste("(", indication, ")", sep=""))
    , las = 2
    )
} else {
  invalidDataPdf(outPdf)
}
