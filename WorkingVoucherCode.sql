



 -- Query Starts Here ---------------------------------------

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET SESSION group_concat_max_len=50000;

DROP TEMPORARY TABLE IF EXISTS BundleRequestDetailsWithResponse;
CREATE TEMPORARY TABLE BundleRequestDetailsWithResponse(search_date DATETIME,client_visitor_id varchar(100),product_ids nvarchar(500));

insert into BundleRequestDetailsWithResponse(search_date,client_visitor_id,product_ids)
select distinct search_date,client_visitor_id,product_ids
from bundle_request_tracking
where bundle_id_list <> ''
and page_type='catalog_product_view' and client_visitor_id <> ''
and client_id = 5 and search_date >= '2016-11-24' and search_date < '2017-01-01'
and SUBSTRING(client_visitor_id, CHAR_LENGTH(client_visitor_id),1) not in ('7','8','9','f');

DROP TEMPORARY TABLE IF EXISTS AllOrderDetailsWithBundleResponse;
CREATE TEMPORARY TABLE AllOrderDetailsWithBundleResponse(unique_order_id int,order_time DATETIME,client_order_id nvarchar(100),
customer_id int,saleItemOrderId int,
product_id varbinary(64),product_name nvarchar(500),product_price decimal(12,4),quantity int,total_price decimal(12,4));

insert into AllOrderDetailsWithBundleResponse(unique_order_id,order_time,client_order_id,customer_id,saleItemOrderId,product_id,product_name,product_price,quantity,total_price)
select distinct so.unique_order_id,so.order_time,so.client_order_id,so.customer_id,item.id AS saleItemOrderId,item.product_id,item.product_name,item.product_price,
item.quantity,(item.product_price * item.quantity) AS total_price
from sale_order so
inner join sale_order_item item on item.unique_order_id = so.unique_order_id
inner join client_product_feed_details feedDetails on feedDetails.client_id = so.client_id
inner join client_product_details productDetails on productDetails.feed_id = feedDetails.feed_id
and productDetails.product_id = item.product_id
inner join (
select distinct DATE_FORMAT(search_date,'%d %b %y') as bundleRequestDate,product_ids,client_visitor_id
from BundleRequestDetailsWithResponse
group by DATE_FORMAT(search_date,'%d %b %y'),product_ids,client_visitor_id) brt on brt.product_ids = item.product_id
and brt.client_visitor_id = so.visitor_id
where so.client_id=5 and item.product_name like '%bareMineral%' and productDetails.product_type = 'simple'
and so.order_time >= '2016-12-01' and so.order_time < '2017-01-01'
and (so.order_status = 'complete' OR so.order_status = 'processing')
and SUBSTRING(so.visitor_id, CHAR_LENGTH(so.visitor_id),1) not in ('7','8','9','f')
and productDetails.internal_product_id in (select distinct bundleItems.internal_product_id
from bundle_product_items bundleItems 
inner join bundles on bundleItems.bundle_id = bundles.bundle_id
where bundles.config_id=4);


DROP TEMPORARY TABLE IF EXISTS BundledProductItemList;
CREATE TEMPORARY TABLE BundledProductItemList(unique_order_id int,order_time DATETIME,client_order_id nvarchar(100),customer_id int,
bundle_id int,saleItemOrderId int,product_id varbinary(64),product_name nvarchar(500),product_price decimal(12,4));

insert into BundledProductItemList(unique_order_id,order_time,client_order_id,customer_id,bundle_id,saleItemOrderId,
product_id,product_name,product_price)
select distinct so.unique_order_id,so.order_time,bo.client_order_id,so.customer_id,bo.bundle_id,item.id AS saleItemOrderId,
item.product_id,item.product_name,item.product_price
from sale_order so 
INNER JOIN bundle_configuration_details bc 
on so.client_id = bc.client_id 
INNER JOIN bundles b on b.config_id = bc.config_id 
INNER JOIN bundle_order_tracking bo on so.client_order_id = bo.client_order_id 
and bo.bundle_id = b.bundle_id 
inner join client_product_feed_details feedDetails ON feedDetails.client_id = bc.client_id
inner join sale_order_item item ON so.unique_order_id=item.unique_order_id
inner join client_product_details productDetails ON productDetails.feed_id = feedDetails.feed_id
and productDetails.product_id = item.product_id
inner join bundle_product_items bundleItems on bundleItems.bundle_id = b.bundle_id
and bundleItems.internal_product_id = productDetails.internal_product_id
and bo.bundle_id = bundleItems.bundle_id
where so.client_id=5 and bc.config_id=4 and productDetails.feed_id=5
and item.product_name like '%bareMineral%'
and so.order_time >= '2016-12-01' and so.order_time < '2017-01-01'
and (so.order_status = 'complete' OR so.order_status = 'processing')
order by so.unique_order_id,so.order_time,bo.client_order_id,bo.bundle_id;

DROP TEMPORARY TABLE IF EXISTS ExistingItemOrderIds;
CREATE TEMPORARY TABLE ExistingItemOrderIds(saleItemOrderId int);

insert into ExistingItemOrderIds(saleItemOrderId)
select saleItemOrderId from AllOrderDetailsWithBundleResponse;

insert into AllOrderDetailsWithBundleResponse (unique_order_id,order_time,client_order_id,customer_id,saleItemOrderId,product_id,product_name,product_price,quantity,total_price)
select unique_order_id,order_time,client_order_id,customer_id,saleItemOrderId,product_id,product_name,product_price,1,product_price
from BundledProductItemList
where saleItemOrderId not in (select saleItemOrderId from ExistingItemOrderIds);

DROP TEMPORARY TABLE IF EXISTS BundleOrderAmoutDetails;
CREATE TEMPORARY TABLE BundleOrderAmoutDetails(unique_order_id int,order_time datetime,client_order_id nvarchar(100),total_order_amount decimal(12,4));

insert into BundleOrderAmoutDetails(unique_order_id,order_time,client_order_id,total_order_amount)
select unique_order_id,order_time,client_order_id,sum(product_price) AS total_order_amount
from BundledProductItemList
group by unique_order_id,order_time,client_order_id;

DROP TEMPORARY TABLE IF EXISTS BundledPrimaryProductList;
CREATE TEMPORARY TABLE BundledPrimaryProductList(unique_order_id int,order_time datetime,client_order_id nvarchar(100),
bundle_id int,primarySaleItemOrderId int);

insert into BundledPrimaryProductList(unique_order_id,order_time,client_order_id,bundle_id,primarySaleItemOrderId)
select distinct so.unique_order_id,so.order_time,bo.client_order_id,bo.bundle_id,min(item.id)
from sale_order so 
INNER JOIN bundle_configuration_details bc 
on so.client_id = bc.client_id 
INNER JOIN bundles b on b.config_id = bc.config_id 
INNER JOIN bundle_order_tracking bo on so.client_order_id = bo.client_order_id 
and bo.bundle_id = b.bundle_id 
inner join client_product_feed_details feedDetails ON feedDetails.client_id = bc.client_id
inner join sale_order_item item ON so.unique_order_id=item.unique_order_id
inner join client_product_details productDetails ON productDetails.feed_id = feedDetails.feed_id
and productDetails.product_id = item.product_id
inner join bundle_product_items bundleItems on bundleItems.bundle_id = b.bundle_id
and bundleItems.internal_product_id = productDetails.internal_product_id
where so.client_id=5 and bc.config_id=4 and productDetails.feed_id=5
and item.product_name like '%bareMineral%'
and so.order_time >= '2016-12-01' and so.order_time < '2017-01-01'
and (so.order_status = 'complete' OR so.order_status = 'processing')
group by so.unique_order_id,so.order_time,bo.client_order_id,bo.bundle_id
order by so.unique_order_id,so.order_time,bo.client_order_id,bo.bundle_id;

DROP TEMPORARY TABLE IF EXISTS AllOrderItemList;
CREATE TEMPORARY TABLE AllOrderItemList(unique_order_id int,order_time DATETIME,client_order_id nvarchar(100),customer_id int,
saleItemOrderId int,product_id varbinary(64),product_name nvarchar(500),product_price decimal(12,4),quantity int,total_price decimal(12,4));

insert into AllOrderItemList(unique_order_id,order_time,client_order_id,customer_id,saleItemOrderId,product_id,product_name,product_price,quantity,total_price)
select distinct so.unique_order_id,so.order_time,so.client_order_id,so.customer_id,item.id AS saleItemOrderId,item.product_id,item.product_name,item.product_price,
item.quantity,(item.product_price * item.quantity) AS total_price
from sale_order so
inner join sale_order_item item on item.unique_order_id = so.unique_order_id
where so.unique_order_id in (select distinct unique_order_id from AllOrderDetailsWithBundleResponse);

DROP TEMPORARY TABLE IF EXISTS TotalOrderSummary;
CREATE TEMPORARY TABLE TotalOrderSummary(unique_order_id int,total_order_amount decimal(12,4));

insert into TotalOrderSummary(unique_order_id,total_order_amount)
select distinct unique_order_id,sum(total_price) as total_order_amount
from AllOrderItemList
group by unique_order_id;

DROP TEMPORARY TABLE IF EXISTS AllOrderList;
CREATE TEMPORARY TABLE AllOrderList(unique_order_id int,order_amount decimal(12,4),total_discount_amount decimal(12,4),
bundle_discount_amount decimal(12,4),other_discount_amount decimal(12,4),other_discount_percentage decimal(12,4));

insert into AllOrderList(unique_order_id,order_amount,total_discount_amount,bundle_discount_amount,other_discount_amount,
other_discount_percentage)
select distinct so.unique_order_id,so.order_amount,ABS(ifnull(so.discount_amount,0)) as total_discount_amount,
ifnull(b.discount_amount,0) as bundle_discount_amount,
(ABS(ifnull(so.discount_amount,0)) - ifnull(b.discount_amount,0)) as other_discount_amount,
((ABS(ifnull(so.discount_amount,0)) - ifnull(b.discount_amount,0))/AO.total_order_amount)*100 as other_discount_percentage
from sale_order so
inner join TotalOrderSummary AO on AO.unique_order_id = so.unique_order_id
left join (select client_order_id,sum(discount_amount) as discount_amount
	   from bundle_order_tracking  
           where bundle_id in (select bundle_id from bundles where config_id=4)
           group by client_order_id) b
on b.client_order_id = so.client_order_id;


DROP TEMPORARY TABLE IF EXISTS TotalOrderAmount;
CREATE TEMPORARY TABLE TotalOrderAmount(unique_order_id int,order_time DATETIME,client_order_id nvarchar(100),customer_id int,order_amount decimal(12,4),bundle_discount_amount decimal(12,4),other_discount_amount decimal(12,4));

insert into TotalOrderAmount(unique_order_id,order_time,client_order_id,customer_id,order_amount)
select unique_order_id,order_time,client_order_id,customer_id,sum(total_price) AS order_amount
from (
	select unique_order_id,order_time,client_order_id,customer_id,total_price
	from AllOrderDetailsWithBundleResponse
) itemList
group by itemList.unique_order_id,itemList.order_time,itemList.client_order_id,itemList.customer_id;

update TotalOrderAmount TOA
inner join AllOrderList AO on AO.unique_order_id = TOA.unique_order_id
set TOA.bundle_discount_amount = AO.bundle_discount_amount,
TOA.other_discount_amount = CASE WHEN AO.other_discount_percentage > 0 THEN ((TOA.order_amount/100)*AO.other_discount_percentage) ELSE 0 END;


DROP TEMPORARY TABLE IF EXISTS AllItemList;
CREATE TEMPORARY TABLE AllItemList(order_time DATETIME,client_order_id nvarchar(100),product_name nvarchar(500),product_price decimal(12,4),quantity int,bundleId varchar(100),is_core_product varchar(10),core_product_price decimal(12,4));

insert into AllItemList(order_time,client_order_id,product_name,product_price,quantity,
bundleId,is_core_product,core_product_price)
select AOD.order_time,AOD.client_order_id,AOD.product_name,AOD.product_price,AOD.quantity,
IFNULL(BPIL.bundle_id,'-') AS bundleId,
CASE WHEN BPPL.primarySaleItemOrderId IS NOT NULL THEN 'Yes' ELSE '-' END AS is_core_product,
CASE WHEN BPPL.primarySaleItemOrderId IS NOT NULL THEN IFNULL(BPIL.product_price,0) ELSE 0 END AS core_product_price
from AllOrderDetailsWithBundleResponse AOD
left join BundledProductItemList BPIL ON BPIL.client_order_id = AOD.client_order_id
and BPIL.saleItemOrderId = AOD.saleItemOrderId and BPIL.product_id = AOD.product_id
and BPIL.order_time = AOD.order_time
left join BundledPrimaryProductList BPPL ON BPPL.order_time = BPIL.order_time
and BPPL.client_order_id = BPIL.client_order_id 
and BPPL.bundle_id = BPIL.bundle_id 
and BPPL.primarySaleItemOrderId = BPIL.saleItemOrderId;


SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;



------------ ENDS here --------------------------------------------------
-------- Day wise AOV ----

select DATE_FORMAT(addtime(TOA.order_time,'01:00:00'),'%d %b %y') AS OrderDate,sum(TOA.order_amount) AS TotalOrderAmount,
sum(IFNULL(BOA.total_order_amount,0)) AS BundleOrderAmount,
sum(IFNULL(al.coreProductPrice,0)) AS CoreProductPrice,
COUNT(TOA.client_order_id) AS NoOfTransactions,
sum(IFNULL(TOA.bundle_discount_amount,0)) AS BundleDiscountAmount,
sum(IFNULL(TOA.other_discount_amount,0)) AS OtherDiscountAmount
from TotalOrderAmount TOA
left join BundleOrderAmoutDetails BOA on BOA.order_time = TOA.order_time
and BOA.client_order_id = TOA.client_order_id
left join (
select order_time,client_order_id,SUM(core_product_price) AS coreProductPrice
 from AllItemList
 group by order_time,client_order_id
) al on al.client_order_id = TOA.client_order_id and al.order_time = TOA.order_time
group by DATE_FORMAT(addtime(TOA.order_time,'01:00:00'),'%d %b %y');

-------------------------------------------------------------------------------
--- Control Group ----------------------------------

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET SESSION group_concat_max_len=50000;

DROP TEMPORARY TABLE IF EXISTS BundleRequestDetailsWithoutResponse;
CREATE TEMPORARY TABLE BundleRequestDetailsWithoutResponse(search_date DATETIME,client_visitor_id varchar(100),product_ids nvarchar(500));

insert into BundleRequestDetailsWithoutResponse(search_date,client_visitor_id,product_ids)
select distinct search_date,client_visitor_id,product_ids
from bundle_request_tracking
where bundle_id_list = ''
and page_type='catalog_product_view' and client_visitor_id <> ''
and client_id = 5 and search_date >= '2016-11-24' and search_date < '2017-01-01'
and SUBSTRING(client_visitor_id, CHAR_LENGTH(client_visitor_id),1) in ('7','8','9','f');

DROP TEMPORARY TABLE IF EXISTS AllItemList;
CREATE TEMPORARY TABLE AllItemList(unique_order_id int,order_time DATETIME,client_order_id nvarchar(100),customer_id int,saleItemOrderId int,
product_id varbinary(64),product_name nvarchar(500),product_price decimal(12,4),quantity int);

insert into AllItemList(unique_order_id,order_time,client_order_id,customer_id,saleItemOrderId,product_id,product_name,product_price,quantity)
select distinct so.unique_order_id,so.order_time,so.client_order_id,so.customer_id,item.id AS saleItemOrderId,item.product_id,item.product_name,item.product_price,
item.quantity
from sale_order so
inner join sale_order_item item on item.unique_order_id = so.unique_order_id
inner join client_product_feed_details feedDetails on feedDetails.client_id = so.client_id
inner join client_product_details productDetails on productDetails.feed_id = feedDetails.feed_id
and productDetails.product_id = item.product_id
inner join (
select distinct DATE_FORMAT(search_date,'%d %b %y') as bundleRequestDate,product_ids,client_visitor_id
from BundleRequestDetailsWithoutResponse
group by DATE_FORMAT(search_date,'%d %b %y'),product_ids,client_visitor_id) brt on brt.product_ids = item.product_id
and brt.client_visitor_id = so.visitor_id
where so.client_id=5 and item.product_name like '%bareMineral%' and productDetails.product_type = 'simple'
and so.order_time >= '2016-12-01' and so.order_time < '2017-01-01' and productDetails.feed_id=5
and (so.order_status = 'complete' OR so.order_status = 'processing')
and SUBSTRING(so.visitor_id, CHAR_LENGTH(so.visitor_id),1) in ('7','8','9','f')
and productDetails.internal_product_id in (select distinct bundleItems.internal_product_id
from bundle_product_items bundleItems 
inner join bundles on bundleItems.bundle_id = bundles.bundle_id
where bundles.config_id=4);


DROP TEMPORARY TABLE IF EXISTS AllOrderItemList;
CREATE TEMPORARY TABLE AllOrderItemList(unique_order_id int,order_time DATETIME,client_order_id nvarchar(100),customer_id int,
saleItemOrderId int,product_id varbinary(64),product_name nvarchar(500),product_price decimal(12,4),quantity int,total_price decimal(12,4));

insert into AllOrderItemList(unique_order_id,order_time,client_order_id,customer_id,saleItemOrderId,product_id,product_name,product_price,quantity,total_price)
select distinct so.unique_order_id,so.order_time,so.client_order_id,so.customer_id,item.id AS saleItemOrderId,item.product_id,item.product_name,item.product_price,
item.quantity,(item.product_price * item.quantity) AS total_price
from sale_order so
inner join sale_order_item item on item.unique_order_id = so.unique_order_id
where so.unique_order_id in (select distinct unique_order_id from AllItemList);

DROP TEMPORARY TABLE IF EXISTS TotalOrderSummary;
CREATE TEMPORARY TABLE TotalOrderSummary(unique_order_id int,total_order_amount decimal(12,4));

insert into TotalOrderSummary(unique_order_id,total_order_amount)
select distinct unique_order_id,sum(total_price) as total_order_amount
from AllOrderItemList
group by unique_order_id;

DROP TEMPORARY TABLE IF EXISTS AllOrderList;
CREATE TEMPORARY TABLE AllOrderList(unique_order_id int,order_amount decimal(12,4),total_discount_amount decimal(12,4),
other_discount_percentage decimal(12,4));

insert into AllOrderList(unique_order_id,order_amount,total_discount_amount,
other_discount_percentage)
select distinct so.unique_order_id,so.order_amount,ABS(ifnull(so.discount_amount,0)) as total_discount_amount,
(ABS(ifnull(so.discount_amount,0))/AO.total_order_amount)*100 as other_discount_percentage
from sale_order so
inner join TotalOrderSummary AO on AO.unique_order_id = so.unique_order_id;


DROP TEMPORARY TABLE IF EXISTS TotalOrderAmount;
CREATE TEMPORARY TABLE TotalOrderAmount(unique_order_id int,order_time DATETIME,client_order_id nvarchar(100),
customer_id int,order_amount decimal(12,4),other_discount_amount decimal(12,4));

insert into TotalOrderAmount(unique_order_id,order_time,client_order_id,customer_id,order_amount)
select unique_order_id,order_time,client_order_id,customer_id,sum(itemList.total_price) AS order_amount
from (
select unique_order_id,order_time,client_order_id,customer_id,(product_price*quantity) AS total_price
from AllItemList
) itemList
group by itemList.unique_order_id,itemList.order_time,itemList.client_order_id,itemList.customer_id;


update TotalOrderAmount TOA
inner join AllOrderList AO on AO.unique_order_id = TOA.unique_order_id
set TOA.other_discount_amount = CASE WHEN AO.other_discount_percentage > 0 THEN ((TOA.order_amount/100)*AO.other_discount_percentage) ELSE 0 END;


SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Day wise AOV --
select DATE_FORMAT(addtime(order_time,'01:00:00'),'%d %b %y') AS OrderDate,sum(order_amount) AS TotalOrderAmount,
COUNT(client_order_id) AS NoOfTransactions,
sum(IFNULL(other_discount_amount,0)) AS OtherDiscountAmount
from TotalOrderAmount
group by DATE_FORMAT(addtime(order_time,'01:00:00'),'%d %b %y');






