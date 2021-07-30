
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


--Proceso de copia de resoluciones--

DECLARE @SQLDianResolutionToCopy AS NVARCHAR(MAX) = 
'declare resolutions_cursor CURSOR FOR ' + 
'SELECT * FROM [' + @CloudMultiTenantNameOrigin + '].[dbo].[DianResolution] 
WHERE TenantID = 0x' + CONVERT(nvarchar(max),  @TenantIdOrigin, 2) + ' AND Prefix + CONVERT(varchar(max), Number) NOT IN' +
'(SELECT Prefix + CONVERT(varchar(max), Number) FROM [' + @CloudMultiTenantNameDestination + '].[dbo].[DianResolution] ' + 
'WHERE TenantID = 0x' + CONVERT(nvarchar(max), @TenantIdDestination, 2) + ')'

DECLARE @SQLUsersID AS NVARCHAR(MAX) = 'SELECT TOP 1 @UsersID = UsersID FROM ' + @CloudMultiTenantNameDestination + '.dbo.Users WHERE TenantID = 0x' + CONVERT(nvarchar(max), @TenantIdDestination, 2)
DECLARE @UsersID as bigint
EXECUTE sp_executesql @SQLUsersID, N'@UsersID VARBINARY(85) OUTPUT', @UsersID OUTPUT

CREATE TABLE #CopiedResolutions (OldCode bigint, NewCode bigint)
Declare @InsertedID as bigint

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
	iif(@TestID is null, 'null', '''' + @TestID + '''') +
	') ' +
	'SET @InsertedID = SCOPE_IDENTITY()'
	--print @InsertSQLResolution
	EXECUTE sp_executesql @InsertSQLResolution, N'@InsertedID bigint OUTPUT', @InsertedID OUTPUT 
	Insert into #CopiedResolutions(OldCode, NewCode) Values (@DianResolutionID, @InsertedID)
    FETCH NEXT FROM resolutions_cursor 
	INTO @DianResolutionID, @Number, @Prefix, @StartNumber, @EndNumber, @AuthorizationDate, @StartDate, @EndDate, @EntryType, @CreatedByDate, @CreatedByUser, @UpdatedByUser, @UpdatedByDate, @TechnicalKey, @TenantID, @EntrySubType, @TestID
END

CLOSE resolutions_cursor
DEALLOCATE resolutions_cursor

--Fin Proceso de copia de resoluciones--

--Proceso de copia de terceros--

DECLARE @SQLThirdPartyToCopy AS NVARCHAR(MAX) = 
'declare third_party_cursor CURSOR FOR ' + 
'SELECT * FROM [' + @CloudMultiTenantNameOrigin + '].[dbo].[ThirdParty] 
WHERE TenantID = 0x' + CONVERT(nvarchar(max),  @TenantIdOrigin, 2) + ' AND Identification NOT IN' +
'(SELECT Identification FROM [' + @CloudMultiTenantNameDestination + '].[dbo].[ThirdParty] ' + 
'WHERE TenantID = 0x' + CONVERT(nvarchar(max), @TenantIdDestination, 2) + ')'

CREATE TABLE #CopiedThirdParties (OldCode bigint, NewCode bigint)

DECLARE @ThirdPartyID AS bigint
DECLARE @Code AS varchar(20)
DECLARE @IdType AS bigint
DECLARE @Identification AS varchar(50)
DECLARE @FullName AS varchar(200)
DECLARE @Email AS varchar(100)
DECLARE @CityCode AS bigint
DECLARE @Phone AS varchar(128)
DECLARE @Address AS varchar(250)
DECLARE @ContactFullName AS varchar(100)
DECLARE @SendEntryType AS tinyint
DECLARE @ContactEmail AS varchar(100)

EXECUTE sp_executesql @SQLThirdPartyToCopy

OPEN third_party_cursor
FETCH NEXT FROM third_party_cursor 
INTO @ThirdPartyID, @Code, @IdType, @Identification, @FullName, @Email, @CityCode, @Phone, @Address, @TenantID, @ContactFullName, @SendEntryType, @ContactEmail

WHILE @@FETCH_STATUS = 0
BEGIN
	Declare @InsertSQLThirdParty as nvarchar(max) = 
	'INSERT INTO ' + @CloudMultiTenantNameDestination + '.dbo.ThirdParty ' + 
	'(Code, IdType, Identification, FullName, Email, CityCode, Phone, Address, ContactFullName, TenantID, SendEntryType, ContactEmail)' +
	'VALUES (' +
	iif(@Code is null, 'null', '''' + @Code + '''') + ',' +
	convert(varchar(max), @IdType) + ',' +
	'''' + @Identification + ''',' +
	'''' + @FullName + ''',' +
	'''' + @Email + ''',' +
	convert(varchar(max), @CityCode) + ',' +
	'''' + @Phone + ''',' +
	'''' + @Address + ''',' +
	'''' + @ContactFullName + ''',' +
	'0x' + CONVERT(nvarchar(max), @TenantIdDestination, 2) + ', ' +
	convert(varchar(max), @SendEntryType) + ',' +
	iif(@ContactEmail is null, 'null', '''' + @ContactEmail + '''') +
	') ' +
	'SET @InsertedID = SCOPE_IDENTITY()'
	--print @InsertSQLThirdParty
	EXECUTE sp_executesql @InsertSQLThirdParty, N'@InsertedID bigint OUTPUT', @InsertedID OUTPUT 
	Insert into #CopiedThirdParties(OldCode, NewCode) Values (@ThirdPartyID, @InsertedID)
    FETCH NEXT FROM third_party_cursor 
	INTO @ThirdPartyID, @Code, @IdType, @Identification, @FullName, @Email, @CityCode, @Phone, @Address, @TenantID, @ContactFullName, @SendEntryType, @ContactEmail
END

CLOSE third_party_cursor
DEALLOCATE third_party_cursor

--Fin Proceso de copia de terceros--

SELECT * FROM #CopiedResolutions
SELECT * FROM #CopiedThirdParties

DROP TABLE #CopiedResolutions
DROP TABLE #CopiedThirdParties