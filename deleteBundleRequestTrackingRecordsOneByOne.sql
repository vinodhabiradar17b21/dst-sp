

DELIMITER //
create procedure deleteBundleRequestTrackingRecordsOneByOne()
begin

  DECLARE ItemId int;
      
       
-- Declare variables used just for cursor and loop control
  DECLARE no_more_rows BOOLEAN DEFAULT FALSE;
      
 -- Declare the cursor
  DECLARE BundleItemIdList_cur CURSOR FOR 
  select id from bundle_request_tracking_old where client_id=5 and client_visitor_id='' order by id desc limit 1000;
      
  -- Declare 'handlers' for exceptions
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows = TRUE;
  
  
OPEN BundleItemIdList_cur;    
  
  the_loop: LOOP

    FETCH BundleItemIdList_cur INTO ItemId;

     IF no_more_rows THEN
        CLOSE BundleItemIdList_cur;
        LEAVE the_loop;
    END IF;  
     
     delete from bundle_request_tracking_old where id=ItemId;
             
    
  END LOOP the_loop;

END //
