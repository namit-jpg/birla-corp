// Pick a Satna leaf item, nudge its progress, and confirm the reason refreshes
// purely via the trigger -> CPMEngine.recalculate -> WBSDelayRiskService chain.
WBS_Item__c leaf = [
    SELECT Id, Name, Code__c, Percent_Complete__c, Project_Delay_Reason__c
    FROM WBS_Item__c
    WHERE Project__c = 'a2tHs00000JSWQ6IAP' AND Code__c = '5.2.1'
    LIMIT 1
];
System.debug('BEFORE reason: ' + leaf.Project_Delay_Reason__c);

// Change progress (this fires WBS_ItemTrigger -> recalculate -> evaluate)
Decimal newPct = (leaf.Percent_Complete__c == 40) ? 45 : 40;
leaf.Percent_Complete__c = newPct;
update leaf;

WBS_Item__c after = [
    SELECT Project_Delay_Reason__c, Delay_Likelihood__c, Delay_Risk_Score__c, Percent_Complete__c
    FROM WBS_Item__c WHERE Id = :leaf.Id
];
System.debug('NEW pct: ' + after.Percent_Complete__c);
System.debug('AFTER reason: ' + after.Project_Delay_Reason__c);
System.debug('Likelihood: ' + after.Delay_Likelihood__c + ' | Score: ' + after.Delay_Risk_Score__c);