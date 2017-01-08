/*
-- *******************************************************************
-- Blog Post Title: Clustering executed SQL Server queries using R
-- Author: Tomaz Kastrun
-- Date: 07.JAN.2017
-- Blog: http://tomaztsql.wordpress.com
-- Twitter: @tomaz_tsql
-- Email: tomaz.kastrun@gmail.com
-- *******************************************************************
*/


--SET STATISTICS PROFILE ON
-- SET STATISTICS PROFILE OFF



USE WideWorldImportersDW;
GO



-- drop statistics table
DROP TABLE IF EXISTS  query_stats_LOG_2;
DROP PROCEDURE IF EXISTS AbtQry;
DROP PROCEDURE IF EXISTS SalQry;
DROP PROCEDURE IF EXISTS PrsQry;
DROP PROCEDURE IF EXISTS OrdQry;
DROP PROCEDURE IF EXISTS PurQry;
GO

-- Clean all the stuff only for the selected db
DECLARE @dbid INTEGER
SELECT @dbid = [dbid] 
FROM master..sysdatabases 
WHERE name = 'WideWorldImportersDW'
DBCC FLUSHPROCINDB (@dbid);
GO

-- for better sample, check that you have Query store turned off
ALTER DATABASE WideWorldImportersDW SET  QUERY_STORE = OFF;


-- CREATE Procedures 

CREATE PROCEDURE AbtQry
(@AMNT AS INTEGER) 
AS

-- an arbitrary query
SELECT 
  cu.[Customer Key] AS CustomerKey
  ,cu.Customer
  ,ci.[City Key] AS CityKey
  ,ci.City
  ,ci.[State Province] AS StateProvince
  ,ci.[Sales Territory] AS SalesTeritory
  ,d.Date
  ,d.[Calendar Month Label] AS CalendarMonth
  ,s.[Stock Item Key] AS StockItemKey
  ,s.[Stock Item] AS Product
  ,s.Color
  ,e.[Employee Key] AS EmployeeKey
  ,e.Employee
  ,f.Quantity
  ,f.[Total Excluding Tax] AS TotalAmount
  ,f.Profit
 
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.[Customer Key] = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.[City Key] = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.[Stock Item Key] = s.[Stock Item Key]
  INNER JOIN Dimension.Employee AS e
    ON f.[Salesperson Key] = e.[Employee Key]
  INNER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date
WHERE
	f.[Total Excluding Tax] BETWEEN 10 AND @AMNT;
GO





CREATE PROCEDURE SalQry
(@Q1 AS INTEGER
,@Q2 AS INTEGER)

AS
-- FactSales Query
SELECT * FROM Fact.Sale
WHERE
	Quantity BETWEEN @Q1 AND @Q2;
GO


CREATE PROCEDURE PrsQry
(@CID AS INTEGER )
AS

-- Person Query
SELECT * 
	FROM [Dimension].[Customer]
	WHERE [Buying Group] <> 'Tailspin Toys' 
	/* OR [WWI Customer ID] > 500 */
	AND [WWI Customer ID] BETWEEN 400 AND  @CID
ORDER BY [Customer],[Bill To Customer];
GO



CREATE PROCEDURE OrdQry
(@CK AS INTEGER)
AS

-- FactSales Query
SELECT 
	* 
	FROM [Fact].[Order] AS o
	INNER JOIN [Fact].[Purchase] AS p 
	ON o.[Order Key] = p.[WWI Purchase Order ID]
WHERE
	o.[Customer Key] = @CK;
GO


CREATE PROCEDURE PurQry
(@Date AS SMALLDATETIME)
AS

-- FactPurchase Query
SELECT *
	FROM [Fact].[Purchase]
		WHERE
		[Date Key] = @Date;
	--[Date KEy] = '2015/01/01'
GO



-- Let's make some test environment query execution

DECLARE @ra DECIMAL(10,2)
SET @ra = RAND()
SELECT CAST(@ra*10 AS INT)

IF @ra  < 0.3333
	BEGIN
	   -- SELECT 'RAND < 0.333', @ra
	   DECLARE @AMNT_i1 INT = 100*CAST(@ra*10 AS INT)
	   EXECUTE AbtQry @AMNT = @AMNT_i1
	   EXECUTE PurQry @DAte = '2015/10/01'
	   EXECUTE PrsQry @CID = 480
	   EXECUTE OrdQry @CK = 0
	   DECLARE @Q1_i1 INT = 1*CAST(@ra*10 AS INT)
	   DECLARE @Q2_i1 INT = 20*CAST(@ra*10 AS INT)
	   EXECUTE SalQry @Q1 = @Q1_i1, @Q2 = @Q2_i1

	END
ELSE 
	IF @ra  > 0.3333 AND @ra < 0.6667
	BEGIN
		-- SELECT 'RAND > 0.333 | < 0.6667', @ra
		EXECUTE PurQry @DAte = '2016/04/29'
		EXECUTE PrsQry @CID = 500
		EXECUTE OrdQry @CK = 207
		DECLARE @AMNT_i2 INT = 500*CAST(@ra*10 AS INT)
		EXECUTE AbtQry @AMNT = @AMNT_i2
		DECLARE @Q1_i2 INT = 2*CAST(@ra*10 AS INT)
	    DECLARE @Q2_i2 INT = 10*CAST(@ra*10 AS INT)
        EXECUTE SalQry @Q1 = @Q1_i2, @Q2 = @Q2_i2

	END
ELSE
	BEGIN
	    -- SELECT 'RAND > 0.6667', @ra
		EXECUTE PrsQry @CID = 520
		EXECUTE OrdQry @CK = 5
	    DECLARE @Q2_i3 INT = 60*CAST(@ra*10 AS INT)
		EXECUTE SalQry @Q1 = 25, @Q2 = @Q2_i3
		DECLARE @AMNT_i3 INT = 800*CAST(@ra*10 AS INT)
		EXECUTE AbtQry @AMNT = @AMNT_i3
		EXECUTE PurQry @DAte = '2015/08/13'

	END
GO 5





-- let us run the query stats and get a headache
-- Source: https://msdn.microsoft.com/en-us/library/ms189741.aspx
SELECT

	(total_logical_reads + total_logical_writes) AS total_logical_io
	,(total_logical_reads / execution_count) AS avg_logical_reads
	,(total_logical_writes / execution_count) AS avg_logical_writes
	,(total_physical_reads / execution_count) AS avg_phys_reads
	,substring(st.text,(qs.statement_start_offset / 2) + 1,  ((CASE qs.statement_end_offset 
																WHEN - 1 THEN datalength(st.text) 
																ELSE qs.statement_end_offset END  - qs.statement_start_offset) / 2) + 1) AS statement_text
	,*
INTO query_stats_LOG_2
FROM
		sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY
total_logical_io DESC



-- ********************************
-- ********************************
-- Analysis Part
-- ********************************
-- ********************************

SELECT 
 [total_logical_io]
,[avg_logical_reads]
,[avg_phys_reads]
,execution_count
,[total_physical_reads]
,[total_elapsed_time]
,total_dop
,left([text],100) AS [text]
,row_number() over (order by (select 1)) as ln
 FROM query_stats_LOG_2





CREATE PROCEDURE [dbo].[SP_Query_Stats_Cluster]
AS
DECLARE @RScript nvarchar(max)

SET @RScript = N'
				 library(cluster)
				 All <- InputDataSet
				 image_file <- tempfile()
				 jpeg(filename = image_file, width = 500, height = 500)
					d <- dist(All, method = "euclidean") 
					fit <- hclust(d, method="ward.D")
					plot(fit,xlab=" ", ylab=NULL, main=NULL, sub=" ")
					groups <- cutree(fit, k=3) 
					rect.hclust(fit, k=3, border="DarkRed")			
				 dev.off()
				 OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))' 


DECLARE @SQLScript nvarchar(max)
SET @SQLScript = N'
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
				 FROM query_stats_LOG_2';

EXECUTE sp_execute_external_script
@language = N'R',
@script = @RScript,
@input_data_1 = @SQLScript
WITH RESULT SETS ((Plot varbinary(max)))

GO


execute  [dbo].[SP_Query_Stats_Cluster]
