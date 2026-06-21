Id projectId = 'a2tHs00000JSWQ6IAP';
WBSDelayRiskService.evaluate(projectId);
Integer sent = WBSDelayAlertService.run(projectId);
System.debug('Notifications sent: ' + sent);