/****** StoredProcedure sp_UpdateCategoryLayers Script Date: 19-06-2017 08:40:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Lars Klindt, Geopartner A/S
-- Create date: 20170619
-- Description:	Createscript for sp_AreaRule, StrateGIS project
-- =============================================
-- After insertion of new features to category, the category needs to be updated, since the complete
-- population area of the category has been either increased or decreased
CREATE PROCEDURE [dbo].[sp_UpdateCategoryLayers] 
	-- the category name, in which to update specified layers
	@CategoryName nvarchar(30) = 'CategoryName',
	@RecalculateLayers bit = 0
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		-- drop previous temp table, if any
	IF OBJECT_ID('tempdb..#tmpcategorylayers') IS NOT NULL
		DROP TABLE #tmpcategorylayers

	-- create temp table for holding intersecting geometries from squarenet
	CREATE TABLE #tmpcategorylayers(id int identity, layer_name varchar(30), output_layer_name varchar(30));
	-- insert intersecting features
	INSERT INTO #tmpcategorylayers 
		SELECT layer_name, output_layer_name 
		FROM category_definition, category
		WHERE category_name = @CategoryName
		AND category_definition.category_id = category.id

	DECLARE @max int = 0;
	SELECT @max = COUNT(id) FROM #tmpcategorylayers
	DECLARE @counter int = 1;

	-- Loop through each featurelayer in order to process the layer
	WHILE @counter <= @max
		BEGIN
			-- prepare declarations
			DECLARE @OutputTableName_value varchar(30)
			SELECT @OutputTableName_value = output_layer_name FROM #tmpcategorylayers WHERE id = @counter

			DECLARE @FeatureClassName_value varchar(30)
			SELECT @FeatureClassName_value = layer_name FROM #tmpcategorylayers WHERE id = @counter

			DECLARE @FIdFieldName_value varchar(30)
			SELECT @FIdFieldName_value = property_value FROM globals WHERE property_name = 'FIdFieldName'

			DECLARE @GeomFieldName_value varchar(30)
			SELECT @GeomFieldName_value = property_value FROM globals WHERE property_name = 'GeometryFieldname'


			-- process layer
			DECLARE	@return_value int = 0;
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
