# Thu 28 Dec 2017

ifn <- c("../work_whig/tophits.csv");

cn <- c(
"acc",
"org",
"qname",
"qlen",
"hname",
"hlen",
"identity",
"qcov",
"hcov",
"expect",
"hdesc",
"hlineage"
);

rf <- read.table(ifn, stringsAsFactors = F, col.names = cn, sep = "\t");

ev <- rf$expect;
evs <- sort(ev)
evz <- evs;
evz[evz == 0] <- 1e-200
plot(evz, log = "y");




ev10 <- -(log10(evz))


evs10 <- sort(ev10, decreasing = T)
plot(evs10);

####################################################


ifn <- c("../work_amfc/tophits.csv");

cn <- c(
"acc",
"org",
"qname",
"qlen",
"hname",
"hlen",
"identity",
"qcov",
"hcov",
"expect",
"hdesc",
"hlineage"
);

rf <- read.table(ifn, stringsAsFactors = F, col.names = cn, sep = "\t");

ev <- rf$expect;
evs <- sort(ev)
evz <- evs;
evz[evz == 0] <- 1e-200
plot(evz, log = "y");




ev10 <- -(log10(evz))


evs10 <- sort(ev10, decreasing = T)
plot(evs10);


