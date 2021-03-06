library(ggplot2)
library(dplyr)
args <- commandArgs(trailingOnly=TRUE)

if (length(args) != 14) {
  print(args)
  stop("Usage: evaluator_bars_per_group_strategy.r common.r input.csv output.pdf granularity groupName strategy evaluator1 unit1 quantity1 indication1 evaluator2 unit2 quantity2 indication2")
}

common <- args[1]
inFile <- args[2]
outPdf <- args[3]
# granularity <- args[4]
groupName <- args[5]
strategy <- args[6]
e1 <- args[7]
u1 <- args[8]
q1 <- args[9]
i1 <- args[10]
e2 <- args[11]
u2 <- args[12]
q2 <- args[13]
i2 <- args[14]

source(common)

res = read.csv(inFile, header=TRUE)

res <- res[res$strategy == strategy,]

res$origin <- paste(res$file, res$focus, res$strategy)

# Select the right data
res1 <- res[res$evaluator == e1,]
res2 <- res[res$evaluator == e2,]

# Make the output numeric
res$output <- suppressWarnings(as.numeric(as.character(res$output)))

# Replace NaN with '0'
res$output <- replace(res$output, is.na(res$output), 0)

dat <- merge(res1, res2, by = "origin")
dat <- dat[!is.na(dat$output.x),]
dat <- dat[!is.na(dat$output.y),]

dat <- dat %>%
	group_by(file.x, output.x, strategy.x) %>%
	summarise(output.y=mean(output.y))

if (length(dat$output.y) != 0) {
  startPdf(outPdf)

  p <- ggplot(dat, aes(output.x, output.y, fill = strategy.x)) +
    geom_bar(stat="identity", position = "dodge") +
    scale_fill_brewer(palette = "Set1") +
    labs(x = e1) + labs(y = e2) +
    geom_smooth(method='lm', formula=y~x, show.legend=FALSE, show_guide = FALSE) +
    theme(legend.position="none")

  if (strategy == "full-background") {
    e2 <- paste("log(", e2, ")", sep="")
    p <- p + scale_y_log10()
  }

  p <- p +
    xlab(paste(e1, paste("(", q1, ")", sep=""))) +
    ylab(paste(e2, paste("(", q2, ")", sep=""))) +
    theme(axis.title.y=element_text(angle = 0))
  print(p)

} else {
  invalidDataPdf(outPdf)
}

