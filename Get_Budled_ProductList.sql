
delimiter //
CREATE PROCEDURE Get_Budled_ProductList(ConfigId int,FeedId int,ClientId int,BundleTypeId int)
BEGIN

 
  DECLARE InternalProductId BIGINT;
  DECLARE ProductPrice DECIMAL(12,4);
  DECLARE AffordabilityUpsellPriceLimit DECIMAL(12,4);
   
       
-- Declare variables used just for cursor and loop control
  DECLARE no_more_rows BOOLEAN DEFAULT FALSE;
      
 -- Declare the cursor.
  DECLARE ProductIdList_cur CURSOR FOR 
  select distinct internal_product_id,price
  from ProductIdList;
      
  -- Declare 'handlers' for exceptions
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows = TRUE;
  
  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  
  SET AffordabilityUpsellPriceLimit = 0;
  
  SELECT ifnull(affordability_upsell_price_limit,0)
  INTO AffordabilityUpsellPriceLimit
  FROM bundle_configuration_details  
  WHERE config_id = ConfigId;


DROP TEMPORARY TABLE IF EXISTS HighRevenueProductIdList;
CREATE TEMPORARY TABLE HighRevenueProductIdList(internal_product_id int,revenue decimal(12,4));

insert into HighRevenueProductIdList(internal_product_id,revenue)
select distinct productDetails.internal_product_id,sum(item.product_price * item.quantity) AS revenue
from sale_order_item item
inner join sale_order so on so.unique_order_id = item.unique_order_id
inner join client_product_feed_details feedDetails ON feedDetails.client_id = so.client_id
inner join client_product_details productDetails on productDetails.product_id = item.product_id
and productDetails.feed_id = feedDetails.feed_id
where so.client_id = ClientId and productDetails.feed_id = FeedId and productDetails.product_status=1
and productDetails.client_product_status=1
and productDetails.visibility <> 'Not Visible Individually'
and productDetails.internal_product_id not in (select internal_product_id from bundle_product_exclusions where config_id=ConfigId)
and productDetails.price > 0
group by productDetails.internal_product_id
order by sum(item.product_price * item.quantity) desc;

DROP TEMPORARY TABLE IF EXISTS ProductIdList;
CREATE TEMPORARY TABLE ProductIdList(internal_product_id int,price decimal(12,4));

  INSERT INTO ProductIdList(internal_product_id,price)
  select distinct productDetails.internal_product_id,CASE WHEN ifnull(productDetails.special_price,0) > 0 THEN productDetails.special_price  
      ELSE ifnull(productDetails.price,0) END AS price
  from bundle_product_items bundledItems 
  inner join bundles b on b.bundle_id = bundledItems.bundle_id
  inner join client_product_details productDetails ON productDetails.internal_product_id = bundledItems.internal_product_id
  where b.config_id=ConfigId and productDetails.feed_id=FeedId 
  and productDetails.product_status=1 and productDetails.client_product_status=1 
  -- and b.bundle_type_id = BundleTypeId
  and b.product_count < 4 and b.status_code=1 and productDetails.price > 0
  and productDetails.internal_product_id not in (select internal_product_id from bundle_product_exclusions where config_id=ConfigId);

  
  DROP TEMPORARY TABLE IF EXISTS BundledProductList;
  CREATE TEMPORARY TABLE BundledProductList(productId bigint,bundledProductUrl nvarchar(2048),bundledProductName nvarchar(200));

OPEN ProductIdList_cur;    
  
  the_loop: LOOP

  FETCH ProductIdList_cur INTO InternalProductId,ProductPrice;

  IF no_more_rows THEN
     CLOSE ProductIdList_cur;
     LEAVE the_loop;
  END IF;  

  INSERT INTO BundledProductList(productId,bundledProductUrl,bundledProductName) 
  SELECT distinct InternalProductId,cpd.product_url AS bundledProductUrl,cpd.product_name AS bundledProductName
  FROM bundle_product_items BItems
  inner join client_product_details cpd on cpd.internal_product_id = BItems.internal_Product_id
  INNER JOIN (
    SELECT distinct bundledItems.bundle_id,purchase_count AS purchaseCount
	FROM bundle_product_items bundledItems
	INNER JOIN bundles ON bundledItems.bundle_id = bundles.bundle_id 
	WHERE bundledItems.internal_product_id = InternalProductId and bundles.config_id=ConfigId and bundles.status_code=1
   -- and bundles.bundle_type_id=BundleTypeId
        and bundledItems.internal_product_id not in (select internal_product_id from bundle_product_exclusions where config_id=ConfigId)
	order by purchase_count desc    
  ) BList ON BList.bundle_id = BItems.bundle_id
  AND BItems.internal_product_id <> InternalProductId
  INNER JOIN bundles B on B.bundle_id = BItems.bundle_id
  WHERE (CASE WHEN ifnull(cpd.special_price,0) > 0 THEN cpd.special_price  
      ELSE ifnull(cpd.price,0) END) <= (ProductPrice + ((ProductPrice/100.00) * AffordabilityUpsellPriceLimit))
  and cpd.internal_product_id not in (select internal_product_id from bundle_product_exclusions where config_id=ConfigId)
  and cpd.product_status=1 and cpd.client_product_status=1 and B.status_code=1 and cpd.price > 0
  order by BList.purchaseCount desc
  limit 5;

     
  END LOOP the_loop;
    
    -- insert into TP_Building_Materials(productId,product_url,BundleList)
  select BpList.productId,cpd.product_url,GROUP_CONCAT(BpList.bundledProductUrl SEPARATOR ',') AS BundleList
  from BundledProductList BpList
  inner join client_product_details cpd 
  on cpd.internal_product_id = BpList.productId
  where cpd.internal_product_id not in (select internal_product_id from bundle_product_exclusions where config_id=ConfigId)
  and cpd.price > 0
  group by BpList.productId,cpd.product_url;
  
  select convert(cpd.product_id,char) as product_id,cpd.product_sku,cpd.product_name,cpd.product_url,
  GROUP_CONCAT(BpList.bundledProductName SEPARATOR ',') AS BundleList
  from BundledProductList BpList
  inner join client_product_details cpd 
  on cpd.internal_product_id = BpList.productId
  where cpd.internal_product_id not in (select internal_product_id from bundle_product_exclusions where config_id=ConfigId)
  and cpd.product_status=1 and cpd.client_product_status=1 and cpd.price > 0
  group by cpd.product_id,cpd.product_name,cpd.product_url;

  select convert(cpd.product_id,char) as product_id,cpd.product_name,cpd.product_url,HRP.revenue,
  GROUP_CONCAT(BpList.bundledProductName SEPARATOR ',') AS BundleList
  from HighRevenueProductIdList HRP
  inner join client_product_details cpd on cpd.internal_product_id = HRP.internal_product_id
  left join BundledProductList BpList ON BpList.productId = cpd.internal_product_id
  where cpd.internal_product_id not in (select internal_product_id from bundle_product_exclusions where config_id=ConfigId)
  and cpd.price > 0
  group by BpList.productId,cpd.product_id,cpd.product_name,cpd.product_url,HRP.revenue
  order by HRP.revenue desc;


SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

  
  END
