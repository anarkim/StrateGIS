/****** StoredProcedure sp_UpdateCategory Script Date: 19-06-2017 08:40:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Lars Klindt, Geopartner A/S
-- Create date: 20170619
-- Description:	sp_AreaRule, StrateGIS project
-- =============================================
-- Updates the complete content of the category, based on a summation of scores  and overlaps from all layers assigned to this category.
-- If the category does not exist, the category output table is created.
-- The category output table name is specified in the 'category' table.
CREATE PROCEDURE [dbo].[sp_UpdateCategory]
	-- the category name, in which to update specified layers
	@CategoryName nvarchar(30) = 'CategoryName'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Category_output_layer_name varchar(30)
	SELECT @Category_output_layer_name = category_output_layer_name FROM category WHERE category_name = @CategoryName

	-- create new table for output of aggragated category calculations
	-- if not existing
   DECLARE @SQLCreateString NVARCHAR(MAX)
   SET @SQLCreateString = 'IF NOT EXISTS (SELECT * FROM sys.tables WHERE name=''' + @Category_output_layer_name + ''')
			CREATE TABLE ' + @Category_output_layer_name + ' (
			[ID] [int] IDENTITY(1,1) NOT NULL,
			[square_id] [nvarchar](30) NOT NULL,
			[category_area_overlap] [float] NOT NULL,
			[category_score] [float] NOT NULL,
			[category_item_percentage_overlap] [float] NULL,
			[category_item_percentage_population] [float] NULL,
			[geom] [geometry] NOT NULL,
				PRIMARY KEY CLUSTERED 
				(
					[ID] ASC
				)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
				) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]'
   EXEC (@SQLCreateString)
   
	-- create refrence in geometry_columns table
   DECLARE @SQLCreateRefInGeometryColumnsString NVARCHAR(MAX)
   SET @SQLCreateRefInGeometryColumnsString = 'IF (SELECT Count(*) FROM geometry_columns WHERE f_table_name=''' + @Category_output_layer_name + ''') = 0
			INSERT INTO geometry_columns (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, geometry_type)
			VALUES (''Svendborg_Vand'', ''dbo'', ''' + @Category_output_layer_name + ''', ''geom'', 2, 25832, ''POLYGON'')'
   EXEC (@SQLCreateRefInGeometryColumnsString)
   
   -- clear table
   DECLARE @SQLDeleteCreateString NVARCHAR(MAX)
   SET @SQLDeleteCreateString = 'DELETE FROM ' + @Category_output_layer_name + ' '
   EXEC (@SQLDeleteCreateString)


		-- drop previous temp table, if any
	IF OBJECT_ID('tempdb..#tmpcategorylayers') IS NOT NULL
		DROP TABLE #tmpcategorylayers

	-- create temp table for holding intersecting geometries from squarenet
	CREATE TABLE #categoryTemp(id int identity, output_layer_name varchar(30));

	INSERT INTO #categoryTemp
		SELECT output_layer_name
		FROM category_definition, category
		WHERE category_name = @CategoryName
		AND category_definition.category_id = category.id
		ORDER BY output_layer_name DESC


	DECLARE @max int = 0;
	SELECT @max = COUNT(id) FROM #categoryTemp
	DECLARE @counter int = 1;


	-- Loop through each featurelayer in order to update complete category
	WHILE @counter <= @max
		BEGIN
			DECLARE @theLayer varchar(30)
			SELECT @theLayer = output_layer_name FROM #categoryTemp WHERE id = @counter


			-- drop previous temp table, if any
			IF OBJECT_ID('tempdb..#SquaresTemp') IS NOT NULL
				DROP TABLE #SquaresTemp
			-- loop through all squares in square_grid table
			-- create temp table for holding intersecting geometries from squarenet
			CREATE TABLE #SquaresTemp(id int identity, square_id varchar(30));

			-- Determine number of iterations in subsequent while loop
			DECLARE @LoopCount int = 0;
			DECLARE @SQLLoopCounter nvarchar(max) = 'INSERT INTO #SquaresTemp SELECT square_id FROM ' + @theLayer + ' GROUP BY square_id'
			-- execute the inline SQL statement, result is stored in tem table
			exec sp_executesql @SQLLoopCounter;


			DECLARE @squaremax int = 1;
			SELECT @squaremax = COUNT(id) FROM #SquaresTemp


			-- Loop through each square to determine sum of areas
			DECLARE @squarecounter int = 1;
			WHILE @squarecounter <= @squaremax
				BEGIN

					DECLARE @theSquareId nvarchar(30)
					SELECT @theSquareId = square_id FROM #SquaresTemp WHERE id = @squarecounter
					SET @theSquareId = '''' + @theSquareId + ''''

					DECLARE @theSquareGeom geometry
					DECLARE @theSquareGeomSQL nvarchar(max) = 'SELECT Top(1) @theSquareGeomOut = geom FROM ' + @theLayer + ' WHERE square_id=' + @theSquareId
					DECLARE @theSquareGeomSQLParmDefinition nvarchar(500);
					SET @theSquareGeomSQLParmDefinition = '@theSquareGeomOut geometry OUTPUT';
					-- execute the inline SQL statement, result is stored in tem table
					exec sp_executesql @theSquareGeomSQL, @theSquareGeomSQLParmDefinition, @theSquareGeomOut = @theSquareGeom OUTPUT;

					-- Determine number of intersection square features
					-- create inline SQL statement
					DECLARE @theSum float = 0; 
					DECLARE @theScore float = 0; 
					DECLARE @SQLKvadratMax nvarchar(max) = 'SELECT @theSumOut = ISNULL(SUM(area_overlap), 0), @theScoreOut = ISNULL(SUM(feature_score), 0) FROM ' + @theLayer + ' WHERE square_id=' + @theSquareId
					DECLARE @MaxParmDefinition nvarchar(500);
					SET @MaxParmDefinition = '@theSumOut float OUTPUT, @theScoreOut float OUTPUT';
					-- execute the inline SQL statement, result is stored in tem table
					exec sp_executesql @SQLKvadratMax, @MaxParmDefinition, @theSumOut = @theSum OUTPUT, @theScoreOut = @theScore OUTPUT;
					
				    IF(@theSum > 0)
						BEGIN
							-- update or insert area
							DECLARE @SQLUpdateInsert nvarchar(max);
							SET @SQLUpdateInsert = 'UPDATE ' + @Category_output_layer_name + ' SET category_area_overlap=category_area_overlap + @theSumIn, category_score=category_score + @theScoreIn
														WHERE ' + @Category_output_layer_name + '.square_id=' + @theSquareId + '
														IF @@ROWCOUNT=0 INSERT INTO ' + @Category_output_layer_name + '
														(square_id, category_area_overlap, category_score, geom)
														VALUES (' + @theSquareId + ', @theSumIn, @theScoreIn, @theSquareGeomIn)'
							DECLARE @SQLUpdateInsertParmDefinition nvarchar(500);
							SET @SQLUpdateInsertParmDefinition = '@theSumIn float, @theScoreIn float, @theSquareGeomIn geometry';
							-- execute the inline SQL statement, result is stored in tem table
							exec sp_executesql @SQLUpdateInsert, @SQLUpdateInsertParmDefinition, @theSumIn = @theSum, @theScoreIn = @theScore, @theSquareGeomIn = @theSquareGeom;
						END					


					SET @squarecounter = @squarecounter + 1
				END
				-- determine complete area for all featureclass features
				DECLARE	@featureClassArea float = 0
				EXEC	@featureClassArea = [dbo].[sp_DetermineLayerCompleteArea]
						@TableName = @Category_output_layer_name,
						@GeometryFieldName = 'geom'


			SET @counter = @counter + 1
		END

	-- update relative area calculations for complete category
	DECLARE @SQLCalculateRelativeAreas nvarchar(max);
	SET @SQLCalculateRelativeAreas = 'UPDATE ' + @Category_output_layer_name + ' SET category_item_percentage_overlap=(category_area_overlap/10000)*100, category_item_percentage_population=(category_area_overlap/@featureClassAreaIn)*100'
	DECLARE @SQLCalculateRelativeAreasParmDefinition nvarchar(500);
	SET @SQLCalculateRelativeAreasParmDefinition = '@featureClassAreaIn float';
	-- execute the inline SQL statement, result is stored in tem table
	exec sp_executesql @SQLCalculateRelativeAreas, @SQLCalculateRelativeAreasParmDefinition, @featureClassAreaIn = @featureClassArea;

	-- return '1' as successfully completion
	return 1

END
