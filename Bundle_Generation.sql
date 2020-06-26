


call Generate_WorldSim_Bundles(43,43);


drop PROCEDURE Generate_WorldSim_Bundles;
DELIMITER //
CREATE PROCEDURE Generate_WorldSim_Bundles(ConfigId INT,FeedId INT)
BEGIN
 
  
  DECLARE BundleId INT;  
  DECLARE NewBundleId INT; 
  
    
-- Declare variables used just for cursor and loop control
  DECLARE no_more_rows BOOLEAN DEFAULT FALSE;
      
 -- Declare the cursor
  DECLARE FBPBundleItemIdList_cur CURSOR FOR 
  SELECT DISTINCT bundle_id
  FROM bundles
  WHERE config_id = 42 AND status_code=1;
      
  -- Declare 'handlers' for exceptions
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows = TRUE;
  
   SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  
OPEN FBPBundleItemIdList_cur;    
  
  the_loop: LOOP

    FETCH FBPBundleItemIdList_cur INTO BundleId;

     IF no_more_rows THEN
        CLOSE FBPBundleItemIdList_cur;
        LEAVE the_loop;
     END IF; 
    
	SET NewBundleId = 0;
    
	INSERT INTO bundles(config_id,bundle_type_id,product_count,purchase_count)
	select ConfigId,bundle_type_id,product_count,purchase_count
    	from bundles 
	where config_id=42 and bundle_id = BundleId;
       
     	SET NewBundleId = LAST_INSERT_ID();
       
    	IF(NewBundleId > 0)
     	THEN
       
       	INSERT INTO bundle_product_items(bundle_id,internal_product_id)
       	SELECT NewBundleId,internal_product_id
	FROM client_product_details 
        WHERE feed_id=FeedId and product_id in (select cpd.product_id
        from client_product_details cpd
        inner join bundle_product_items bpi on bpi.internal_product_id = cpd.internal_product_id
	    WHERE bpi.bundle_id = BundleId);
         
    	END IF;
        
  END LOOP the_loop;
  
END //
