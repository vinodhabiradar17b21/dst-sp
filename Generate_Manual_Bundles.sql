
call Generate_Manual_Bundles(15,5,5);


DELIMITER //
CREATE PROCEDURE Generate_Manual_Bundles(ConfigId INT,BundleTypeId INT,PurchaseCountIncrementer INT)
BEGIN

  DECLARE FrequentlyBoughtPatternId BIGINT;
  DECLARE FrequentlyBoughtPattern VARCHAR(1000);
  DECLARE PurchaseCount INT;  
  DECLARE ItemCount INT;
  
  DECLARE BundleId INT;
  DECLARE ExistingBundleId INT;
  DECLARE InternalProductId INT;

  
  DECLARE ValueSeparator VARCHAR(10);
  DECLARE StringValue VARCHAR(8000);
  DECLARE CurrentIndex INT;
      
       

  DECLARE no_more_rows BOOLEAN DEFAULT FALSE;
      
 
  DECLARE FBPBundleItemIdList_cur CURSOR FOR 
  SELECT DISTINCT fbp_id
  FROM frequently_bought_together_items
  WHERE config_id = ConfigId;
      
  
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows = TRUE;
  
  SET ValueSeparator = ',';
  
OPEN FBPBundleItemIdList_cur;    
  
  the_loop: LOOP

    FETCH FBPBundleItemIdList_cur INTO FrequentlyBoughtPatternId;

     IF no_more_rows THEN
        CLOSE FBPBundleItemIdList_cur;
        LEAVE the_loop;
    END IF;  
     
     SET BundleId = 0;
     SET FrequentlyBoughtPattern = '';
     SET PurchaseCount = 0;
     SET ItemCount = 0;
     SET ExistingBundleId = 0;
     SET InternalProductId = 0;
       
     SELECT frequent_item_set,purchase_count,item_count,existing_bundle_id
     INTO  FrequentlyBoughtPattern,PurchaseCount,ItemCount,ExistingBundleId
     FROM frequently_bought_together_items
     WHERE fbp_id = FrequentlyBoughtPatternId;
       
     SET StringValue = FrequentlyBoughtPattern;
     
     DROP TEMPORARY TABLE IF EXISTS SplitFrequentlyBoughtPatternItemIdList;
     CREATE TEMPORARY TABLE SplitFrequentlyBoughtPatternItemIdList(id int auto_increment primary key,internal_product_id bigint); 
 
     WHILE(LOCATE(ValueSeparator,StringValue) > 0)  
     DO  
  SET CurrentIndex = LOCATE(ValueSeparator,StringValue);
    
  INSERT INTO SplitFrequentlyBoughtPatternItemIdList(internal_product_id) 
  VALUES (SUBSTRING(StringValue, 1 , CurrentIndex-1));

  SET StringValue = SUBSTRING(StringValue, CurrentIndex + LENGTH(ValueSeparator), LENGTH(StringValue)); 
    
     END WHILE;
          
          
      IF (StringValue <> '') THEN
    INSERT INTO SplitFrequentlyBoughtPatternItemIdList(internal_product_id) 
    VALUES(StringValue);  
      END IF;
      
      SET InternalProductId = (select internal_product_id from SplitFrequentlyBoughtPatternItemIdList where id=1);
      
     SET PurchaseCount = (select b.purchase_count
	 from bundle_product_items items
	 inner join bundles b on b.bundle_id = items.bundle_id
	 inner join client_product_details cpd on cpd.internal_product_id = items.internal_product_id
	 where b.bundle_type_id <> 13 and items.bundle_id in (
	 select bundle_id from bundle_product_items where internal_product_id = InternalProductId)
	 and items.internal_product_id <> InternalProductId
	 order by b.purchase_count desc limit 1);
     
     SET PurchaseCount = PurchaseCount + PurchaseCountIncrementer;
       
	 SELECT PurchaseCount;
     
     IF(ExistingBundleId IS NOT NULL AND ExistingBundleId > 0 AND PurchaseCount > 0) THEN
     
      UPDATE bundles B
      INNER JOIN frequently_bought_together_items F ON F.config_id = B.config_id AND F.existing_bundle_id = B.bundle_id
      SET B.purchase_count = PurchaseCount,B.last_action_date = now(),B.bundle_type_id = BundleTypeId,
      B.status_code=1
      WHERE B.config_id = ConfigId;
     
     ELSE
      
       INSERT INTO bundles(config_id,bundle_type_id,product_count,purchase_count)
       VALUES(ConfigId,BundleTypeId,ItemCount,PurchaseCount);
       
       SET BundleId = LAST_INSERT_ID();
       
       IF(BundleId > 0) THEN
       
       INSERT INTO bundle_product_items(bundle_id,internal_product_id)
       SELECT BundleId,internal_product_id
       FROM SplitFrequentlyBoughtPatternItemIdList;
         
       END IF;
	END IF;
    
  END LOOP the_loop;
  
   DELETE FROM frequently_bought_together_items WHERE config_id = ConfigId;
 
END