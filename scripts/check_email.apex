List<EmailMessage> msgs = [SELECT Id, Subject, ToAddress, Status, MessageDate FROM EmailMessage ORDER BY MessageDate DESC LIMIT 10];
for (EmailMessage m : msgs) {
    System.debug(m.MessageDate + ' | ' + m.Status + ' | ' + m.ToAddress + ' | ' + m.Subject);
}
System.debug('Total recent emails: ' + msgs.size());