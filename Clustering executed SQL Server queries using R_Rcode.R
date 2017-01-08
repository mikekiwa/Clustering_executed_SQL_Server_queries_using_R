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
                      ,CASE WHEN LEFT([text],70) LIKE '%AbtQry%' THEN 'AbtQry'
          							 WHEN LEFT([text],70) LIKE '%OrdQry%' THEN 'OrdQry'
          							 WHEN LEFT([text],70) LIKE '%PrsQry%' THEN 'PrsQry'
          							 WHEN LEFT([text],70) LIKE '%SalQry%' THEN 'SalQry'
          							 WHEN LEFT([text],70) LIKE '%PurQry%' THEN 'PurQry'
          							 WHEN LEFT([text],70) LIKE '%@BatchID%' THEN 'System'
          						ELSE 'Others' END AS label_graph 
                      FROM query_stats_LOG_2")

close(myconn) 


library(cluster)

#qd <- query.data[,c(1,2,3,5,6)]
qd <- query.data[,c(1,2,6)]

## hierarchical clustering
qd.use <- query.data[,c(1,2,6)]
medians <- apply(qd.use,2,median)
mads <- apply(qd.use,2,mad)
qd.use <- scale(qd.use,center=medians) #,scale=mads)

#calculate distances
query.dist <- dist(qd.use)

# hierarchical clustering
query.hclust <- hclust(query.dist)

# plotting solution
op = par(bg = "lightblue")
plot(query.hclust,labels=query.data$label_graph,main='Query Hierarchical Clustering', ylab = 'Distance', xlab = ' ', hang = -1, sub = "" )
# in addition to circle queries within cluster
rect.hclust(query.hclust, k=3, border="DarkRed")		



# we get 3 clusters
groups.3 = cutree(query.hclust,3)


# PAM: Partitioning Around Medoids
library(cluster)
query.pam <- pam(query.dist,3)

# compare results from hierarchical clustering and PAM
table(groups.3,query.pam$clustering)

# both solutions seem to agree on queries clusters
plot(query.pam)

