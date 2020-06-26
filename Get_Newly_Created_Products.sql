

-- Query to get newly created products in last week based on impressions.



DELIMITER // 
CREATE PROCEDURE Get_Newly_Created_Products(ClientId INT,FeedId INT,ConfigId INT,CreationDate datetime)
BEGIN

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

select distinct product_name,
product_url,tList.impressionCount
from client_product_details productDetails
inner join (
select distinct product_id,count(product_id) AS impressionCount
from product_view_tracking
where client_id=ClientId
group by product_id) tList on tList.product_id = productDetails.product_id
inner join client_product_category_mapping cpcm on cpcm.internal_product_id = productDetails.internal_product_id
inner join client_product_feed_details feedDetails on feedDetails.feed_id = productDetails.feed_id
inner join bundle_configuration_details configDetails on configDetails.client_id = feedDetails.client_id
where productDetails.feed_id=FeedId and productDetails.created_date >= CreationDate and configDetails.config_id= ConfigId
and product_status=1 and client_product_status=1 and feedDetails.client_id = ClientId
and ((configDetails.configurable_product_bundles_allowed=0 and productDetails.product_type='simple') OR 
(configDetails.configurable_product_bundles_allowed=1 and (productDetails.product_type='simple' OR productDetails.product_type='configurable')))
and productDetails.internal_product_id not in (select internal_product_id from bundle_product_items items
inner join bundles b on b.bundle_id = items.bundle_id
where b.config_id=ConfigId)
and productDetails.internal_product_id not in (select internal_product_id from bundle_product_exclusions)
and cpcm.internal_category_id not in (select internal_category_id from bundle_category_exclusions where config_id=ConfigId)
order by tList.impressionCount desc
limit 100;

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

END //
