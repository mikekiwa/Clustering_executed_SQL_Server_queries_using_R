library(RODBC)

myconn <-odbcDriverConnect("driver={SQL Server};Server=SICN-KASTRUN;database=WideWorldImportersDW;trusted_connection=true")


query.data <- sqlQuery(myconn, "
                      SELECT 
					             [total_logical_io]
                      ,[avg_logical_reads]
                      ,[avg_phys_reads]
                      ,execution_count
                      ,[total_physical_reads]
                      ,[total_elapsed_time]
                      ,total_dop
                      ,[text]
                      ,LEFT([text],35) AS label_graph 
                      FROM query_stats_LOG_2")

close(myconn) 


library(cluster)

qd <- query.data[,c(1,2,3,5,6)]

## hierarchical clustering
qd.use <- query.data[,c(1,2,3,5,6)]
medians <- apply(qd.use,2,median)
mads <- apply(qd.use,2,mad)
qd.use <- scale(qd.use,center=medians,scale=mads)

#calculate distances
query.dist <- dist(qd.use)

# hierarchical clustering
query.hclust <- hclust(query.dist)

# plotting solution
plot(query.hclust,labels=query.data$label_graph,main='Default from hclust')

# we get 3 clusters
groups.3 = cutree(query.hclust,3)


# PAM: Partitioning Around Medoids
library(cluster)
query.pam <- pam(query.dist,3)

# compare results from hierarchical clustering and PAM
table(groups.3,query.pam$clustering)

# both solutions seem to agree on queries clusters


plot(query.pam)

