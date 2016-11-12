trigger ChatterBotTopicAssignmentTrigger on TopicAssignment ( after insert ) {
    
    // Initialize variables to store objects/ids    
    List<TopicAssignment> topicAssignmentList = new List<TopicAssignment>();    
    Set<Id> topicIdList = new Set<Id>();
    Set<Id> feedItemList = new Set<Id>();
    
    // Used later to correlate a topic name to a feed item
    Map<String,String> topicNameMap = new Map<String,String>();
    Map<FeedItem,String> feedTopicMap = new Map<FeedItem,String>(); 
    Map<FeedItem,String> feedItemIdMap = new Map<FeedItem,String>();
        
    // Create list of ids for reference later
    for( TopicAssignment assignment : Trigger.new ) { 
        
        // There are multiple types of EntityType's for a TopicAssignment
        // so filter to FeedItem
        if( assignment.EntityType == 'FeedItem' ) {  
            
            topicAssignmentList.add( assignment );
            topicIdList.add( assignment.TopicId );
            feedItemList.add( assignment.EntityId );
            
        }
        
    }  
    
    // Create map of topic names for reuse later and to bulkify queries
    for( Topic topic : [SELECT Id, Name FROM Topic WHERE Id IN :topicIdList ] ) {    
        topicNameMap.put( topic.Id, topic.Name );    
    }
    
    // Query all feed items related to the topic assignments
    for( FeedItem feedItem : [SELECT Id, ParentId, Body FROM FeedItem WHERE Id IN :feedItemList ] ) {    
        
        // tie feed item to topic name. the key should be the feed item id since
        // there is a chance that multiple topic assignments could be done in the same
        // batch for a particular topic
        for( TopicAssignment assignment : topicAssignmentList ) {              
            if( feedItem.Id == assignment.EntityId ) {
                feedTopicMap.put( feedItem, topicNameMap.get( assignment.TopicId ) );
                feedItemIdMap.put( feedItem, assignment.EntityId );
            }            
        }       
        
    }

    // Query for a list of chatter bots that are active and match any of the
    // topic names 
    List<Chatter_Bot_Topic__c> chatterBotConfigList = [
        SELECT 
            Id, 
            Topic_Name__c
        FROM 
            Chatter_Bot_Topic__c
        WHERE 
            Topic_Name__c IN :topicNameMap.values() 
            AND 
            Active__c = true
    ];
    
    List<Chatter_Bot_Topic_Assignment__c> chatterBotTopicAssignmentList = new List<Chatter_Bot_Topic_Assignment__c>();
    
    if( chatterBotConfigList.size() > 0 ) {
        
        for( Chatter_Bot_Topic__c chatterBot : chatterBotConfigList ) { 
            
            for( FeedItem feedItem : feedTopicMap.keySet() ) {
                
                // get topic name
                String topicName = feedTopicMap.get( feedItem );
                
                if( topicName == chatterBot.Topic_Name__c ) {
                    
                    Chatter_Bot_Topic_Assignment__c assignment = new Chatter_Bot_Topic_Assignment__c(
                        Chatter_Bot__c = chatterBot.Id,
                        Topic__c = topicName,
                        Feed_Item_Id__c = feedItem.Id,
                        Feed_Item_Parent_Id__c = feedItem.ParentId,
                        Feed_Item_Body__c = feedItem.Body
                    );               
                    
                    chatterBotTopicAssignmentList.add( assignment );   
                    
                }
                
            }
            
        }
        
        insert chatterBotTopicAssignmentList;
        
    }     

}