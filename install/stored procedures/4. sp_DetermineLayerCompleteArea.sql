/****** StoredProcedure sp_DetermineLayerCompleteArea Script Date: 19-06-2017 08:40:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Lars Klindt, Geopartner A/S
-- Create date: 20170619
-- Description:	sp_DetermineLayerCompleteArea, StrateGIS project
-- =============================================
-- Since multiple geometries can overlap the same grid cells, the complete overlap has to be calculated complete as a sum of all overlaps for cells
-- with similar geometry.
-- This stored procedure will do the summation and return the complete area
CREATE PROCEDURE [dbo].[sp_DetermineLayerCompleteArea]
	-- Add the parameters for the stored procedure here
	@TableName nvarchar(30) = 'TableName',
	@GeometryFieldName nvarchar(30) = 'GeometryFieldName'

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Detmermine the complete surface area from specified layers geometry columns
	DECLARE
		@counter    INT = 1,
		@max        INT = 0,
		@completearea Float = 0

	-- Declare a variable of type TABLE. It will be used as a temporary table.
	--DECLARE @myTable TABLE (
	--	ID		int identity,
	--	[geom]		geometry
	--)

	-- Insert your required data in the variable of type TABLE
	-- run nested sql statement
	-- fetch row count into variable @max
	CREATE TABLE #myTable(id int identity, geom geometry);
	DECLARE @SQLInsert nvarchar(max) = 'INSERT INTO #myTable select ' + @GeometryFieldName + ' from '+ @TableName	
	exec sp_executesql @SQLInsert
	
	--sp_executesql 'INSERT INTO #tempTable SELECT ' + @GeometryFieldName + ' FROM ' + @TableName	;
	--SELECT * FROM #tempTable;

	--DECLARE @insertQry varchar(255)
	--SET @insertQry = 'INSERT INTO @myTable select ' + @GeometryFieldName + ' from '+ @TableName	
	--EXEC @insertQry
	
	
	-- run nested sql statement
	-- fetch row count into variable @max
	DECLARE @SQLMax nvarchar(max) = 'SELECT @maxOUT = count(' + @GeometryFieldName + ') from ' + @TableName
	DECLARE @MaxParmDefinition nvarchar(500);
	SET @MaxParmDefinition = '@maxOUT INT OUTPUT';
	exec sp_executesql @SQLMax, @MaxParmDefinition, @maxOUT=@max OUTPUT;

	-- Loop 
	WHILE @counter <= @max
	BEGIN
		-- get the row in the loop and add the records area to the resulting area
		DECLARE @partialGeom geometry;
		SET @partialGeom = (SELECT geom FROM #myTable WHERE ID = @counter);

		SET @completearea = @completearea + @partialGeom.STArea()
		SET @counter = @counter + 1
	END

	RETURN @completearea
END
