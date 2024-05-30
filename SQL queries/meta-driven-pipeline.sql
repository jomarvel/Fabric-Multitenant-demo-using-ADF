-- This is for creating a metadata driven pipeline. In this scenario you will have 3 Azure SQL Databases with the sample db installed.
-- The scenario is for populating a "warehouse" from multiple databases where each database holds one tenant's data
-- This IS NOT an example of datawarehouse design/data modeling best practices.
-- Create this in either a dedicated config database or possibly the warehouse. The best practice would be to use a config database, especially if you need to do other things like storing position markers for each table.
-- I have chossen to go pretty bare-bones here, the idea is that I will use the tenant id to retrieve the servername and database name which are the bare minimum needed for connection assuming that I use either managed identity or a hardcoded username and password to connect

CREATE TABLE TenantMetaData
(
   TenantPriority INT,
   TenantID VARCHAR(100),
   ServerName VARCHAR(100),
   DataBaseName VARCHAR(100),
)

-- This just populates for my multi-tenant example, you will very likely have different servernames at a minimum
INSERT INTO TenantMetaData
VALUES (1,  'tenant1', 'db-host.database.windows.net', 'db-tenant1');

INSERT INTO TenantMetaData
VALUES (2, 'tenant2', 'db-host.database.windows.net', 'db-tenant2');

INSERT INTO TenantMetaData
VALUES (3, 'tenant3', 'db-host.database.windows.net', 'db-tenant3');

/* Tables in this database, the schema is always SalesLT *
Address
Customer
CustomerAddress
Product
ProductCategory
ProductDescription
ProductModel
ProductModelProductDescription
SalesOrderDetail
SalesOrderHeader
*/

CREATE TABLE SchemaMetadata (
   CopyPriority int, -- Usefull for ordered copying of tables
	SchemaName VARCHAR(100),
	TableName VARCHAR(100),
	CopyFlag bit
	);


-- Note that the order is based on the RI requirements of the source. This may be different on the destination or RI may not exist at all
INSERT INTO SchemaMetadata
VALUES (1, 'SalesLT', 'Address', 1);

INSERT INTO SchemaMetadata
VALUES (2, 'SalesLT', 'Customer', 1);

INSERT INTO SchemaMetadata
VALUES (3, 'SalesLT', 'CustomerAddress', 1);

INSERT INTO SchemaMetadata
VALUES (4, 'SalesLT', 'ProductCategory', 1);

INSERT INTO SchemaMetadata
VALUES (5, 'SalesLT', 'ProductModel', 1);

INSERT INTO SchemaMetadata
VALUES (6, 'SalesLT', 'ProductDescription', 1);

INSERT INTO SchemaMetadata
VALUES (7, 'SalesLT', 'ProductModelProductDescription', 1);

INSERT INTO SchemaMetadata
VALUES (8, 'SalesLT', 'Product', 1);

INSERT INTO SchemaMetadata
VALUES (9, 'SalesLT', 'SalesOrderHeader', 1);

INSERT INTO SchemaMetadata
VALUES (10, 'SalesLT', 'SalesOrderDetail', 1);

INSERT INTO test.dbo.SchemaMetadata
VALUES (10, 'SalesLT', 'SalesOrderDetail', 1);
