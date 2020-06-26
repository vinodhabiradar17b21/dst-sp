


DELIMITER //
CREATE PROCEDURE Insert_Bulk_Order_Details(ClientId int,PlatformId int,out result int)
BEGIN

INSERT INTO customer(email,name,first_name,last_name)
SELECT distinct email,replace(name,'  ',' ') as name,first_name,last_name
FROM bulk_order_details_temporary_storage
WHERE client_id = ClientId AND email IS NOT NULL
AND email NOT IN (select distinct email from customer)
AND id in (
select distinct id
from (
SELECT max(id) AS id
FROM bulk_order_details_temporary_storage 
group by email
) elist)
order by email;


INSERT INTO sale_order(client_id,platform_id,client_order_id,order_status,order_amount,order_time,
coupon_code,discount_amount,tax_amount,shipping_amount,shipping_method,currency_code,payment_method,
user_ip,customer_id,increasingly_version,user_agent,visitor_id)
SELECT distinct OD.client_id,OD.platform_id,OD.client_order_id,OD.order_status,OD.order_amount,
OD.order_time,OD.coupon_code,OD.discount_amount,OD.tax_amount,
OD.shipping_amount,OD.shipping_method,OD.currency_code,
OD.payment_method,OD.user_ip,IFNULL(c.id,0) AS customerId,OD.increasingly_version,OD.user_agent,OD.visitor_id
FROM bulk_order_details_temporary_storage OD		
LEFT JOIN customer c ON c.email = OD.email
WHERE OD.client_id = ClientId;


INSERT INTO sale_order_item(unique_order_id,product_id,product_name,product_price,product_url,
product_sku,product_type,quantity)
SELECT DISTINCT SO.unique_order_id,OI.product_id,OI.product_name,OI.product_price,OI.product_url,
OI.product_sku,OI.product_type,OI.quantity
FROM bulk_order_item_details_temporary_storage OI
INNER JOIN (select distinct client_id,unique_order_id,client_order_id from sale_order where client_id=ClientId) SO 
ON SO.client_id = OI.client_id and
SO.client_order_id = OI.client_order_id
WHERE OI.client_id = ClientId;

SET result=1;

truncate table bulk_order_item_details_temporary_storage;
truncate table bulk_order_details_temporary_storage;

END //