
DECLARE @CloudTenantCompanyKeyOrigin AS NVARCHAR(MAX) = 'HierrosdelCafeII'
DECLARE @CloudTenantCompanyKeyDestination AS NVARCHAR(MAX) = 'COMERCIALIZADORA_DISTRILLANTAS_SAS_01'
DECLARE @Nit AS NVARCHAR(MAX) = '900842338'

DECLARE @CloudMultiTenantNameOrigin AS NVARCHAR(MAX) = (
SELECT CloudMultiTenantName FROM [eSiigoCloudControl].[dbo].[CloudMultiTenant]
WHERE CloudMultiTenantID in 
	(
	SELECT DISTINCT CloudMultiTenantCode 
	FROM [eSiigoCloudControl].[dbo].[CloudTenant]
	WHERE CloudTenantCompanyKey = @CloudTenantCompanyKeyOrigin
	)
)

DECLARE @CloudMultiTenantNameDestination AS NVARCHAR(MAX) = (
SELECT CloudMultiTenantName FROM [eSiigoCloudControl].[dbo].[CloudMultiTenant] 
WHERE CloudMultiTenantID in 
	(
	SELECT DISTINCT CloudMultiTenantCode 
	FROM [eSiigoCloudControl].[dbo].[CloudTenant] 
	WHERE CloudTenantCompanyKey = @CloudTenantCompanyKeyDestination
	)
)

DECLARE @CloudTenantCodeOrigin AS UNIQUEIDENTIFIER = (
SELECT CloudTenantID FROM [eSiigoCloudControl].[dbo].[CloudTenant]
WHERE CloudTenantCompanyKey = @CloudTenantCompanyKeyOrigin
)

DECLARE @CloudTenantCodeDestination AS UNIQUEIDENTIFIER= (
SELECT CloudTenantID FROM [eSiigoCloudControl].[dbo].[CloudTenant]
WHERE CloudTenantCompanyKey = @CloudTenantCompanyKeyDestination
)

DECLARE @SQLSelectOrigin AS NVARCHAR(MAX) = 'SELECT @TenantID = TenantID FROM [' + @CloudMultiTenantNameOrigin + '].[dbo].[Company] WHERE CloudTenantCode = ''' + CONVERT(nvarchar(max), @CloudTenantCodeOrigin) + ''''
DECLARE @SQLSelectDestination AS NVARCHAR(MAX) = 'SELECT @TenantID = TenantID FROM [' + @CloudMultiTenantNameDestination + '].[dbo].[Company] WHERE CloudTenantCode = ''' + CONVERT(nvarchar(max), @CloudTenantCodeDestination) + ''''

DECLARE @TenantIdOrigin AS VARBINARY(85)
DECLARE @TenantIdDestination AS VARBINARY(85)

EXECUTE sp_executesql @SQLSelectOrigin, N'@TenantID VARBINARY(85) OUTPUT', @TenantIdOrigin OUTPUT
EXECUTE sp_executesql @SQLSelectDestination, N'@TenantID AS VARBINARY(85) OUTPUT', @TenantIdDestination OUTPUT


DECLARE @SQLDianResolutionOrigin AS NVARCHAR(MAX) = 'SELECT * FROM [' + @CloudMultiTenantNameOrigin + '].[dbo].[DianResolution] WHERE TenantID = 0x' + CONVERT(nvarchar(max), @TenantIdOrigin, 2)
DECLARE @SQLDianResolutionDestination AS NVARCHAR(MAX) = 'SELECT * FROM [' + @CloudMultiTenantNameDestination + '].[dbo].[DianResolution] WHERE TenantID = 0x' + CONVERT(nvarchar(max), @TenantIdDestination, 2)

--CREATE TABLE #CopiedResolutions (OldCode bigint, NewCode bigint)

DECLARE @SQLDianResolutionToCopy AS NVARCHAR(MAX) = 
'declare resolutions_cursor CURSOR FOR ' + 
'SELECT * FROM [' + @CloudMultiTenantNameOrigin + '].[dbo].[DianResolution] 
WHERE TenantID = 0x' + CONVERT(nvarchar(max),  @TenantIdOrigin, 2) + ' AND Prefix + CONVERT(varchar(max), Number) NOT IN' +
'(SELECT Prefix + CONVERT(varchar(max), Number) FROM [' + @CloudMultiTenantNameDestination + '].[dbo].[DianResolution] ' + 
'WHERE TenantID = 0x' + CONVERT(nvarchar(max), @TenantIdDestination, 2) + ')'

DECLARE @SQLUsersID AS NVARCHAR(MAX) = 'SELECT TOP 1 @UsersID = UsersID FROM ' + @CloudMultiTenantNameDestination + '.dbo.Users WHERE TenantID = 0x' + CONVERT(nvarchar(max), @TenantIdDestination, 2)
DECLARE @UsersID as bigint
EXECUTE sp_executesql @SQLUsersID, N'@UsersID VARBINARY(85) OUTPUT', @UsersID OUTPUT

Declare @DianResolutionID bigint
Declare @Number bigint
Declare @Prefix varchar(5)
Declare @StartNumber bigint
Declare @EndNumber bigint
Declare @AuthorizationDate datetime
Declare @StartDate datetime
Declare @EndDate datetime
Declare @EntryType tinyint
Declare @CreatedByDate datetime
Declare @CreatedByUser bigint
Declare @UpdatedByUser bigint
Declare @UpdatedByDate datetime
Declare @TechnicalKey nvarchar(64)
Declare @TenantID varbinary(85)
Declare @EntrySubType tinyint
Declare @TestID nvarchar(50)

EXECUTE sp_executesql @SQLDianResolutionToCopy

OPEN resolutions_cursor
FETCH NEXT FROM resolutions_cursor 
INTO @DianResolutionID, @Number, @Prefix, @StartNumber, @EndNumber, @AuthorizationDate, @StartDate, @EndDate, @EntryType, @CreatedByDate, @CreatedByUser, @UpdatedByUser, @UpdatedByDate, @TechnicalKey, @TenantID, @EntrySubType, @TestID

WHILE @@FETCH_STATUS = 0
BEGIN
    --PRINT CONVERT(nvarchar(max), @DianResolutionID) + ' ' + @Prefix + ' - ' + CONVERT(nvarchar(max), @Number)
	Declare @InsertSQLResolution as nvarchar(max) = 
	'INSERT INTO ' + @CloudMultiTenantNameDestination + '.dbo.DianResolution ' + 
	'(Number, Prefix, StartNumber, EndNumber, AuthorizationDate, StartDate, EndDate, EntryType, CreatedByDate, CreatedByUser, TechnicalKey, TenantID, EntrySubType, TestID)' +
	'VALUES (' +
	convert(varchar(max), @Number) + ',' +
	'''' + @Prefix + ''',' +
	convert(varchar(max), @StartNumber) + ',' +
	convert(varchar(max), @EndNumber) + ',' +
	'''' + convert(varchar(max), @AuthorizationDate, 13) + ''',' +
	'''' + convert(varchar(max), @StartDate, 13) + ''',' +
	'''' + convert(varchar(max), @EndDate, 13) + ''',' +
	convert(varchar(max), @EntryType) + ',' +
	'''' + convert(varchar(max), GETDATE(), 13) + ''',' +
	convert(varchar(max), @UsersID) + ',' +
	'''' + @TechnicalKey + ''',' +
	'0x' + CONVERT(nvarchar(max), @TenantIdDestination, 2) + ', ' +
	convert(varchar(max), @EntrySubType) + ',' +
	'''' + isnull(@TestID, '') + '''' +
	')'
	print @InsertSQLResolution
	EXECUTE sp_executesql @InsertSQLResolution
    FETCH NEXT FROM resolutions_cursor 
	INTO @DianResolutionID, @Number, @Prefix, @StartNumber, @EndNumber, @AuthorizationDate, @StartDate, @EndDate, @EntryType, @CreatedByDate, @CreatedByUser, @UpdatedByUser, @UpdatedByDate, @TechnicalKey, @TenantID, @EntrySubType, @TestID
END

CLOSE resolutions_cursor
DEALLOCATE resolutions_cursor

--EXECUTE sp_executesql @SQLDianResolutionOrigin
--EXECUTE sp_executesql @SQLDianResolutionDestination

--DROP TABLE #CopiedResolutions