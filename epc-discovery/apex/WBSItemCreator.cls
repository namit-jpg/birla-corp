/**
 * @description Invocable Apex class to create WBS_Item__c records from a Flow.
 * This class accepts a list of input records containing Baseline Start,
 * Baseline Finish, and Project ID, and returns a list of the names
 * of the newly created WBS_Item__c records.
 */
public with sharing class WBSItemCreator {

    /**
     * @description Inner class to define the input variables for the invocable method.
     * The @InvocableVariable annotation is required for each variable
     * to be accessible from a Flow.
     */
    public class WBSItemInput {
        @InvocableVariable(label='Baseline Start Date' description='The start date for the WBS Item baseline.')
        public Date baselineStart;
        
        @InvocableVariable(label='Baseline Finish Date' description='The finish date for the WBS Item baseline.')
        public Date baselineFinish;
        
        @InvocableVariable(label='Project ID' description='The ID of the related Project__c record.')
        public Id projectId;

        @InvocableVariable(label='template name' description='the template name.')
        public string templatename;
        
    }

    /**
     * @description Inner class to define the output variable for the invocable method.
     * This will hold the Name of the created WBS_Item__c record.
     */
    public class WBSItemOutput {
        @InvocableVariable(label='WBS Item Name' description='The Name of the newly created WBS Item.')
        public String wbsItemName;
    }

    /**
     * @description Invocable method to create WBS_Item__c records.
     * @param inputs A list of WBSItemInput objects passed from the Flow.
     * @return A list of WBSItemOutput objects containing the Name of the created records.
     */
    @InvocableMethod(label='Create WBS Items' description='Creates WBS_Item__c records and returns their names.')
    public static List<WBSItemOutput> createWBSItems(List<WBSItemInput> inputs) {
        
        // List to hold the new WBS_Item__c records to be inserted.
        List<WBS_Item__c> itemsToCreate = new List<WBS_Item__c>();

        // List to hold the output names to be returned to the Flow.
        List<WBSItemOutput> outputs = new List<WBSItemOutput>();

        // Check for empty or null inputs.
        if (inputs != null && !inputs.isEmpty()) {
            for (WBSItemInput input : inputs) {
                // Create a new SObject record for each input.
                WBS_Item__c newItem = new WBS_Item__c();
               // newItem.Name__c = input.templatename;
                newItem.Baseline_Start__c = input.baselineStart;
                newItem.Baseline_Finish__c = input.baselineFinish;
                newItem.Project__c = input.projectId;
                
                // Add the new record to the list for DML operation.
                itemsToCreate.add(newItem);
            }
        }

        // Use a try-catch block for safe DML operations.
        if (!itemsToCreate.isEmpty()) {
            try {
                // Insert the new records.
                insert itemsToCreate;

                // Loop through the successfully inserted records to get their names.
                for (WBS_Item__c createdItem : itemsToCreate) {
                    WBSItemOutput output = new WBSItemOutput();
                    output.wbsItemName = createdItem.Name;
                    System.debug('Created WBS Item Name: ' + createdItem.Name);
                    outputs.add(output);
                }
                
                // Debug the list of output names.
                System.debug('Created WBS Items Names: ' + outputs);

            } catch (DmlException e) {
                // Log any DML exceptions and return an empty list.
                // You could also add a custom error message to the output list
                // for the Flow to handle.
                System.debug('DML Exception: ' + e.getMessage());
                return new List<WBSItemOutput>();
            }
        }

        return outputs;
    }
}