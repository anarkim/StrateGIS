/****** StoredProcedure sp_CalculateAllLayersInCategory Script Date: 19-06-2017 08:40:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Lars Klindt, Geopartner A/S
-- Create date: 20170619
-- Description:	sp_CalculateAllLayersInCategory, StrateGIS project
-- =============================================
-- This stored procedure will calculate all layers with the specified category, by category name. 
-- All rules for each layer will be applied in order to update the property feature_score.
-- Please note: depending on the number of layers in the category and the complexity and number of rules
-- this stored procedure may execute for some time, before it is complete.
-- Please note: If one layer table is assigned to more than one category, this tables calculated feature_score is flushed and may affect other categories
-- The property RecalculateLayers determines if the grid in each of the table is recalculated (may take some time)
CREATE PROCEDURE [dbo].[sp_CalculateAllLayersInCategory] 
	-- the category table name, in which to store the
	-- intersecting features and feature properties
	@CategoryName nvarchar(30) = 'CategoryName',
	@RecalculateLayers bit = 0

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		-- drop previous temp table, if any
	IF OBJECT_ID('tempdb..#categoryTemp') IS NOT NULL
		DROP TABLE #categoryTemp

	-- create temp table for holding intersecting geometries from squarenet
	CREATE TABLE #categoryTemp(id int identity, layer_name varchar(30), output_layer_name varchar(30));

	INSERT INTO #categoryTemp
		SELECT layer_name, output_layer_name
		FROM category_definition, category
		WHERE category_name = @CategoryName
		AND category_definition.category_id = category.id
		ORDER BY layer_name DESC

	-- Determine number of intersection square features
	-- create inline SQL statement
	DECLARE @max int = 0; 
	SELECT @max = count(id) from #categoryTemp
	DECLARE @counter int = 1; 

	-- Loop through each featurelayer and process calculations
	WHILE @counter <= @max
		BEGIN
			-- determine complete area for all featureclass features
			DECLARE @OutputTableName_value VARCHAR (30)
			SELECT @OutputTableName_value = output_layer_name FROM #categoryTemp WHERE id=@counter

			DECLARE @FeatureClassName_value VARCHAR (30)
			SELECT @FeatureClassName_value = layer_name FROM #categoryTemp WHERE id=@counter

			DECLARE @FIdFieldName_value VARCHAR (30)
			SELECT @FIdFieldName_value = property_value FROM globals WHERE property_name='FIdFieldName'

			DECLARE @GeomFieldName_value VARCHAR (30)
			SELECT @GeomFieldName_value = property_value FROM globals WHERE property_name='GeometryFieldname'


			DECLARE	@return_value int = 0
			EXEC	@return_value = [dbo].[sp_CalculateLayer]
					@OutputTableName = @OutputTableName_value,
					@FeatureClassName = @FeatureClassName_value,
					@FIdFieldName = @FIdFieldName_value,
					@GeomFieldName = @GeomFieldName_value,
					@RecalculateFeatures = @RecalculateLayers

			SET @counter = @counter + 1
		END

	-- return '1' as successfully completion
	return 1
END
