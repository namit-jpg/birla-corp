Organization org = [SELECT Id, Name, DefaultLocaleSidKey FROM Organization LIMIT 1];
System.debug('Org: ' + org.Name);
// Check deliverability via OrgEmailAddresses
List<OrgEmailAddress> oes = [SELECT Id, DisplayName, Address, IsAllowAllProfiles FROM OrgEmailAddress LIMIT 5];
for (OrgEmailAddress o : oes) System.debug('OrgEmail: ' + o.Address + ' | AllProfiles: ' + o.IsAllowAllProfiles);