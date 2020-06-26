


call Update_Existing_Bundle_Data_Manual(15,5);

DROP PROCEDURE Update_Existing_Bundle_Data_Manual;

DELIMITER //
CREATE PROCEDURE Update_Existing_Bundle_Data_Manual(ConfigId INT,BundleTypeId INT)
BEGIN

DECLARE exit handler for sqlexception
BEGIN
    
  DELETE FROM frequently_bought_together_items;    
 
END;
  
  DELETE FROM frequently_bought_together_items WHERE purchase_count < 2;
  DELETE FROM frequently_bought_together_items WHERE config_id=17 and item_count > 2;

  DROP TEMPORARY TABLE IF EXISTS ExistingBundleItemList;
  CREATE TEMPORARY TABLE ExistingBundleItemList(bundle_id int,bundle_list varchar(1000),purchase_count int,config_id int);

SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; 

  INSERT INTO ExistingBundleItemList(bundle_id,bundle_list,config_id)
  SELECT bundleItems.bundle_id,
         GROUP_CONCAT(bundleItems.internal_product_id ORDER BY bundleItems.internal_product_id SEPARATOR ',') AS BundleList,
	 bundles.config_id
  FROM bundle_product_items bundleItems
  INNER JOIN bundles ON bundles.bundle_id = bundleItems.bundle_id
  WHERE bundles.config_id = ConfigId
  GROUP BY bundleItems.bundle_id;
  
  DROP TEMPORARY TABLE IF EXISTS ExistingBundleIdDetails;
  CREATE TEMPORARY TABLE ExistingBundleIdDetails(fbp_id bigint,bundle_id int);
  
  INSERT INTO ExistingBundleIdDetails(fbp_id,bundle_id)
  SELECT F.fbp_id,EB.bundle_id
  FROM frequently_bought_together_items F
  INNER JOIN ExistingBundleItemList EB ON F.config_id = EB.config_id AND F.frequent_item_set = EB.bundle_list
  WHERE F.config_id = ConfigId;


  UPDATE frequently_bought_together_items F
  INNER JOIN ExistingBundleIdDetails EBD ON F.fbp_id = EBD.fbp_id 
  SET F.existing_bundle_id = EBD.bundle_id
  WHERE F.config_id = ConfigId;
  
 
  IF(ConfigId = 27) THEN

    CALL Apply_RutlandCycling_Bundle_Generation_Rules(27);   
  
  END IF;


END //

