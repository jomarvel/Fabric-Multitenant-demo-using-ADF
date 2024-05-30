# Fabric OneLake Multi-tenant demo using ADF

This demo is provided as-is and is not supported in any way by me or Microsoft. Feel free to provide feedback but I can not guarantee that it will be addressed.

The demo is designed to highlight one way in one scenario to build multi-tenant, reusable pipelines using Microsoft Fabric OneLake and Azure Data Factory. This demo will showcase using ADF pipelines to bring in data from 3 different SQL DBs and copy data to OneLake.  When Fabric pipelines are able to [paramterize connections](https://learn.microsoft.com/en-us/fabric/release-plan/data-factory#enabling-customers-parameterize-connections), I'll create another repo using only Fabric.  But until that feature release, we will utilize ADF. 

## Prerequisites
+ An Active Azure Subscription
+ A Microsoft Fabric Capacity. If you or your organization do not have a fabric capacity, you can take advantage of the [trial capacity.](https://learn.microsoft.com/en-us/fabric/get-started/fabric-trial)

## Demo Guide
### Deploy Azure resources
Please use the Deploy to Azure button to deploy the Azure resources needed for this demo.  All resources should be deployed to the same Azure region. Since this is a demo only, I would also recommend deploying to the same resource group. 

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2FAzure%2FFabric-Multitenant%2Fblob%2Fmain%2Farm%2520templates%2Fresources_arm_templates.json)

__Paramaters for template that need to be added:__ 
+ Unique lowercase data factory name
+ Unique lowercase storage account name
+ Unique lowercase unique SQL server Name
+ Admin login
+ Admin password

-For this demo we deploy three Azure SQL Databases with sample data. These are all hosted from the same Logical SQL Server. I use the S2 tier during the demo but scale down to S1 when I am not actively using it. I also enable SQL Authentication. The pipeline will use SQL Authentication so for ease of use I would use the same admin account for all of your databases. The best practice security wise would be to use a Managed Identity in Data Factory and grant access to SQL databases. Also make sure that your databases are using a public endpoint for this demo.  

-We will also deploy an Azure Data Factory and an Azure Storage account

> Note: Once deployed, you should see 1 SQL server, 3 SQL DBs, 1 storage account, and 1 data factory instance in your resource group.

![image](https://github.com/Azure/Fabric-Multitenant/assets/111533671/cb07abd7-cffc-48b2-8e76-48802a064ceb)

### Deploy the ARM pipeline ARM template

> __Note__: This step is required. This step is not covered in the previous arm template deployment. The previous section is for deploying Azure resources while this step deploys your Data Factory Pipeline.

1. Open Azure Data Factory in the Azure Portal and click on __Open Azure Data Factory Studio__. 

2. Select the __Manage__ icon on the left, choose __ARM template__, and select __Import ARM template__. This should launch the __Custom deployment__ page in the Azure portal.

3. Select __Build your own template in the editor__ and leave it open for now.

4. Open the __arm_templates\adf_pipeline_arm_template.json__ file in this repository. Select all of the text and then paste it into the __Edit template__ page and click __Save__.

5. Now choose the __resource group__ and __region__ that you are deploying into, update the __Factory Name__ to reflect your data factory name. There's one connection string you will need to populate. Below is an example examples of what these should look like (without the quotes). The highlighted value will need to be changed to your admin login you choose at the beginning of this tutorial.  The rest of the template can be ignored.  

    __Tenant Databases_connectionString =__ integrated security=False;encrypt=True;connection timeout=30;data source=@{linkedService().ServerName};initial catalog=@{linkedService().DatabaseName};user id=`dblogin`

    > __Note__: The tenant database connection string is parameterized for the data source and initial catalog values. The pipeline will automatically fill in these values at run time.

6. Select __Review + create__, then choose the __Create__ button. Give the template a few minutes to deploy. Close and reopen your Azure Data Factory Studio and verify that you ARM template has successfully deployed by navigating to the __Author__ page. Here you should now have two pipelines and three datasets.

### Configure Fabric Workspace

1.  Navigate to [https://app.fabric.microsoft.com](https://app.fabric.microsoft.com).  This will bring up the homescreen of Fabric.  We're first going to create a new workspace, so click on __Workspaces__ on the leftside blade and then click on __+ New Workspace__.
   
   ![image](https://github.com/Azure/Fabric-Multitenant/assets/111533671/c69f5816-5a50-43b6-ad2d-d5cb18050e4d)

2.  Go ahead and give the workspace a Name, something like __Multitenant Demo__ if it's available.  Everything else can be skipped over, click __Apply__ to create the workspace.

### Create Data Warehouse
1. You should now be inside of your newly created workspace.  Go ahead and click on the image that's most likely powerBI in the bottom left corner.  You should see a list of all the Fabric capabilities.  Click __Data Warehouse__.

   ![image](https://github.com/Azure/Fabric-Multitenant/assets/111533671/44929b09-aff4-4a93-a877-65c98c0b4242)

2. Now click on the __Warehouse__ button at the top to create a new Warehouse.
   
   ![image](https://github.com/Azure/Fabric-Multitenant/assets/111533671/87cc7f44-aa28-4ab7-8ebd-5d9b44bb1b6c)

3. Provide your Warehouse a name and click Apply.  Your new Warehouse should automatically open up, give it a minute for the warehouse to load.  

### Configure your metadata tables
This solution leverage the use of metadata tables in the OneLake Warehouse to store the server names, database names and tenant ids for the source databases. It also stores a list of table names that we would like to copy in our pipeline.

1.  In your newly created Warehouse, Click __New SQL Query__ at the top of the screen.

2. Open the __SQL Queries\meta-driven-pipeline.sql__ file found in this repo in a text editor. You __WILL__ need to update the insert statements for the TenantMetadata table with the correct ServerNames for your environment. The parts you must changed are highlighted below.

     INSERT INTO TenantMetaData
    VALUES (1,  'tenant1', '`db-host`.database.windows.net', 'db-tenant1');

   INSERT INTO TenantMetaData
    VALUES (2, 'tenant2', '`db-host`.database.windows.net', 'db-tenant2');

     INSERT INTO TenantMetaData
    VALUES (3, 'tenant3', '`db-host`.database.windows.net', 'db-tenant3');


3. The rest of the script may remain as-is.  Paste the SQL query into Query editor in your warehouse and click __Run__.
   
4. You can now verify that your new metadata tables have been created in your warehouse.  Click under Schemas -> dbo -> Tables.  You may need to click under more options for your tables and click refresh.

![image](https://github.com/Azure/Fabric-Multitenant/assets/111533671/8acaeff1-ce29-461b-bc99-93fb4e816d1f)

### Configure App Registration for service principal authentication

1. Return to the Azure portal and search for __"App Registrations"__ in the top search bar.  Then click __+ New registration__ at the top left.
   
2. Provide a __Name__ for your app registration.  All other default values can be left.

3. In your newly created App registration, click __Certificates & Secrets__ and then click __+ New client secret__.  Finish adding the client secret by clicking __Add__

4. Open a textFile editor, copy and paste the following values for future configurations.

        -Application(client) ID: xxxx
   
        -Directory(tenant) ID: xxxx
   
        -client secret value: xxxx

5. Return to your Fabric workspace and click __Manage Access__, then click __+ Add people or groups__.  Search for the name of the app registration you just created, and provide it with contributor access.

   ![image](https://github.com/Azure/Fabric-Multitenant/assets/111533671/f1edc616-bac5-4b95-95f0-529050d155dc)

   ![image](https://github.com/Azure/Fabric-Multitenant/assets/111533671/de5d0cee-21c7-4940-864e-0a958d05c06f)

   ![image](https://github.com/Azure/Fabric-Multitenant/assets/111533671/e47c5961-1b9b-406e-ab33-c94fb33c538d)

### Configure your Pipelines and linked services

1. To run the pipeline you will need to supply passwords/configurations for the linked services. Linked services hold the connection information for your sources and destinations. From the Azure Data Factory Studio, navigate to __Manage__->__Linked Services__->__TenantDatabases__. Update the __User name__ and __Password__ to match your source databases. 

    >__Note__: At this point the __Test connection__ will not work for this linked service without you manually updating the values for the __Fully qualified domain name ***@{linkedService().ServerName}***__ and the __DatabaseName ***@{linkedService().DatabaseName}***__ parameters. If you scroll down on the__Edit linked service__ blade, you should see a parameters section with the parameterized values we are using. So if you want to test the connect, there will be a popout allowing you to provide those parameters manually (you may leave tenant-id set to the default for connection testing. When we run the pipeline, these parameterized values will be automatically populated from the tables we created earlier.

2. Select __Apply__ to accept the changes.

3. Open the __Warehouse1__ linked service. Here you will update the configuration for your Fabric Warehouse.  Change the Warehouse selection method to __From Selection__.  Verify you are in the correct tenant -> Choose the workspace name that you created for this demo -> Choose the Warehouse name you created.

4. Next, in the authentication reference method leave it at __Inline__.  Next we will provide the values from our app registration.

       -Tenant = Insert the directory(tenant) ID value
   
       -Service principal ID = Insert the Application (client) ID
   
       -Service principal credential type =  Leave it at __Service principal key__
   
       -Service principal key = enter the client secret value

5. Confirm everything was entered correctly by testing the connection using the button at the bottom right.  Upon success, click __Apply__ to accept the changes.

6. Lastly, we will configure our Staging Blob linked service.  Click on the __StagingBlob__ linked service.  Here you can simply change the Account selection method to __From Azure subsription__.  Choose the subscription you have your resource group in, and then choose the storage account name that was created from ARM template.  Go ahead and test the connection again.  Upon completion, apply the changes.


### Understanding the pipelines, activities, datasets and linked services

This solution contains two pipelines and three datasets. Each will be described in detail below. 

The first pipeline is the __TenantPipeline__. This is the master pipeline. When running the demo, it is only necessary to trigger this pipeline, all other components of the demo are automated.

The __TenantPipeline__ consists of three activities described below.

1. The __TenantLookup__ lookup activity. This activity is responsible for pulling the list of tenants by running the ___SELECT * FROM TenantMetadata ORDER BY TenantPriority___ query in the warehouse database. There is no parameterization in this activity but the output which will be passed on to the next activity is JSON formatted with the results of the query that will look something like this:  
    ```json
    {
    "count": 3,
    "value": [
        {
            "TenantPriority": 1,
            "TenantID": "tenant1",
            "ServerName": "db-host.database.windows.net",
            "DatabaseName": "db-tenant1"
        },
        {
            "TenantPriority": 2,
            "TenantID": "tenant2",
            "ServerName": "db-host.database.windows.net",
            "DatabaseName": "db-tenant2"
        },
        {
            "TenantPriority": 3,
            "TenantID": "tenant3",
            "ServerName": "db-host.database.windows.net",
            "DatabaseName": "db-tenant3"
        }
    ]
    }
    ```

    >__Note__: In many production workloads, these metadata tables would be in a dedicated config database, especially if you have lots of rows, or lots of pipelines leveraging the tables, or if the source and or destination databases are in another region.

3. The next activity is the __ForEachTenant__ ForEach activity. If you select this activity, then choose the __Settings__ tab, you will see that under __Items__ we have added dynamic content representing the output of the previous lookup activity. The value is ___@activity('TenantLookup').output.value___. If you delete this item, click in the empty field and choose the __Add dynamic content__ link you will get a popup showing you all of the accessible options for dynamic content. Choose __TenantLookup value array__, which will give you the entire array of results from your lookup. The ForEach activity will then iterate through each element of the array. Note that ForEach loops are not recursive so nested arrays will not processed by the loop.

    On the __Settings__ tab of your __ForEachTenant__ activity, notice there is a __Sequential__ checkbox. Enabling this allows your loop to process only one iteration at a time. In this condition, the loop will wait for the iteration to complete until the next one begins. The default behavior is is for the iterations to all run as soon as possible. Since we would like to process all tenants in parallel, we have left this option disabled.

4. Within your __ForEachTenant__ activity you have the __ExecCopyDatabasePipeline__ activity. This is an an Execute Pipeline activity. We are using it to execute the DatabaseCopyPipeline for each tenant. If you open the __ExecCopyDatabasePipeline__ activity and click on the __Settings__ tab, you will see the name of the invoked pipeline. You will also notice that we have defined three parameters here; __ServerName__, __DatabaseName__ and __TenantID__. These parameters will be passed into the invoked pipeline. If you delete one of these items and then click the __Add dynamic content__ link, you will be taken to the add dynamic content popup. Choose __ForEachTenant__ under the __ForEach iterator__ section. This will show __@item()__ in the editing box. But the item that we are iterating on is actually an array with one element for each column. So to properly assign the value from the array to the parameter type ___.column-name___ replacing column-name with the name of the parameter you deleted, your line should look something like this ___@item().ServerName___. Click __OK__, then publish any changes.

5. Open the __DatabaseCopyPipeline__ under the Factory Resources menu. This pipeline is responsible for collecting the list of tables that we want to copy from each source and then copying each of those tables to the warehouse staging tables. Notice that on the __Parameters__ tab, we have the same parameters that we had in our Execute Pipeline activity. These parameters will be populated by the calling pipeline.

6. The __LookupTables__ lookup activity. This activity is responsible for pulling the list of tables we would like to copy from the source databases by running the ___SELECT * FROM SchemaMetadata WHERE CopyFlag = 1 ORDER BY CopyPriority___ query in the warehouse. The ORDER BY on the __CopyPriority__ column allows us to copy tables in a certain order if necessary by changing the values in the table. The __SchemaName__ and __TableName__ columns should be self-explanitory. The __CopyFlag__ is not used in the demo but it could be used to allow the exclusion of certain tables from the copy process by filtering on this column. There is no parameterization in this activity but the output which will be passed on to the next activity is JSON formatted with the results of the query that will look something like this:
    ```json
    {
    "count": 10,
    "value": [
        {
            "CopyPriority": 1,
            "SchemaName": "SalesLT",
            "TableName": "Address",
            "CopyFlag": true
        },
        {
            "CopyPriority": 2,
            "SchemaName": "SalesLT",
            "TableName": "Customer",
            "CopyFlag": true
        },
        {
            "CopyPriority": 3,
            "SchemaName": "SalesLT",
            "TableName": "CustomerAddress",
            "CopyFlag": true
        },
        {
            "CopyPriority": 4,
            "SchemaName": "SalesLT",
            "TableName": "ProductCategory",
            "CopyFlag": true
        },
        {
            "CopyPriority": 5,
            "SchemaName": "SalesLT",
            "TableName": "ProductModel",
            "CopyFlag": true
        },
        {
            "CopyPriority": 6,
            "SchemaName": "SalesLT",
            "TableName": "ProductDescription",
            "CopyFlag": true
        },
        {
            "CopyPriority": 7,
            "SchemaName": "SalesLT",
            "TableName": "ProductModelProductDescription",
            "CopyFlag": true
        },
        {
            "CopyPriority": 8,
            "SchemaName": "SalesLT",
            "TableName": "Product",
            "CopyFlag": true
        },
        {
            "CopyPriority": 9,
            "SchemaName": "SalesLT",
            "TableName": "SalesOrderHeader",
            "CopyFlag": true
        },
        {
            "CopyPriority": 10,
            "SchemaName": "SalesLT",
            "TableName": "SalesOrderDetail",
            "CopyFlag": true
        }
    ]
    }
    ```

7. The next activity is the __ForEachTable__ ForEach activity. If you select this activity, then choose the __Settings__ tab, you will see that under __Items__ we have added dynamic content representing the output of the previous lookup activity. The value is ___@activity('LookupTables').output.value___. Notice that on this ForEach loop we have chosen to make the loop sequential so that we only copy one table at a time. This is not strictly necessary as we have no referential integrity being enforced on the destination tables but in cases where you do this can be used to load tables in the correct order. 

8. Finally we have the __CopyTable__ activity. This copy data activity is what actually moves data from the source to the destination. 

    Open the __CopyTable__ activity and select the __Source__ tab. Here we define the source dataset __TenantData__ that we will copy data from. __TenantData__ is a parameterized dataset that in turn uses the __TenantDatabases__ parameterized Linked Service. You can see the list of dataset properties that we are using here. The __SchemaName__ and __TableName__ properties are being populated by values from our lookup and __DatabaseName__, __ServerName__ and __TenantID__ are pipeline parameters that were passed in via the execute pipeline activity in the __TenantPipeline__.

    If you scroll to the bottom of the __Source__ tab you will notice a section called __Additional columns__. This adds a new column to every table and populates it with the __TenantID__ pipeline parameter. This allows us to differentiate similar rows in the warehouse that belong to different tenants. For example, if two tenants have an order with the same orderID, you would need a way to differentiate one from the other. 

    Now move to the __Sink__ tab. Here we are copying data into the __StagingData__ dataset. It takes one parameter, __StagingTable__, which is populated with the __TableName__ value passed in during the lookup. If you open the dataset you will see that we are using the __warehouse1__ linked service. For the table, we have hard coded the schema to __staging__ and are using the dataset property __StagingTable__ for the table name.

   If you move to the __Settings__ tab, you will see that we have enabled Staging. This is why we created the storage account and the storage accounts linked service, the data will be temporaily stored in blob storage before it's copied to oneLake Warehouse.

### Running the pipeline

1. If you have any unpublished changes, publish them now.

2. Navigate to the __TenantPipeline__. Remember this is our master pipeline and as such we kick off our copy process from here. This pipeline takes no input from the user, it will collect all the information it needs to complete the copy from our metadata tables.

3. Click the __Add trigger__ button and choose __Trigger now__ from the dropdown and click __OK__ on the popup.

### Monitor the pipelines

You can monitor the progress of the pipelines by selecting the __Monitor__ tab on the left menu. If your pipeline is not making progress, click the refresh button near the top of the page.  You should see your TenantPipeline run once, and the DatabaseCopyPipeline ran three times.

Clicking into the CopyTable jobs we can see the journey our data went on.  

![image](https://github.com/Azure/Fabric-Multitenant-demo-using-ADF/assets/111533671/6df64cb0-0012-46e4-827a-8655fb12868c)

Your DatabaseCopyPipeline's should have all failed.  If you click into the runs, you'll see that only one of the CopyTable operations failed causing the entire ForEachTable opeartion to fail.  

![image](https://github.com/Azure/Fabric-Multitenant-demo-using-ADF/assets/111533671/256eba72-9102-4029-9898-252f70a299f1)

The reason this failed is because the AdventureWorks sampled dataset we configured in our Databases has a table column of type varbinary(MAX).  [This data type is not currently available in fabric.](https://learn.microsoft.com/en-us/sql/t-sql/data-types/binary-and-varbinary-transact-sql?view=sql-server-ver16#limitations)  As you are building in Fabric it's important to review the limiations and differences, this will help in your decision guide.  
