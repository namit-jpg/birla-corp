public class SlackOpportunityChannelService {

    @InvocableMethod(label='Create Opportunity Slack Channel' description='Creates a Slack channel for an Opportunity')
    public static void createOpportunityChannel(List<OpportunityRequest> requests) {
        for (OpportunityRequest req : requests) {
            createOpportunityChannelFuture(req.opportunityId, req.opportunityName, req.accountName);
        }
    }

    @future(callout=true)
    private static void createOpportunityChannelFuture(Id opportunityId, String opportunityName, String accountName) {
        try {
            String token = SlackApiClient.loadConfig().botToken;
            String channelName = buildOpportunityChannelName(accountName, opportunityName);
            String channelId = SlackChannelService.resolveOrCreateChannelPublic(token, channelName);

            List<String> memberIds = SlackChannelService.getUserGroupMembersPublic(token, 'S0B970J8V9D');
            if (!memberIds.isEmpty()) {
                SlackChannelService.inviteUsersToChannelPublic(token, channelId, memberIds);
            }

            String vanceUserId = null;
            try {
                vanceUserId = SlackChannelService.findUserByNamePublic(token, 'vance');
                if (String.isNotBlank(vanceUserId)) {
                    SlackChannelService.inviteUsersToChannelPublic(token, channelId, new List<String>{ vanceUserId });
                }
            } catch (Exception vanceEx) {
                System.debug(LoggingLevel.WARN, 'Could not find or add Vance user: ' + vanceEx.getMessage());
            }

            sendOpportunityMessage(token, channelId, opportunityName, accountName);

            update new Opportunity(Id = opportunityId, Slack_Channel_Id__c = channelId);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SlackOpportunityChannelService error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    private static void sendOpportunityMessage(String token, String channelId, String opportunityName, String accountName) {
        String groupMention = '<!subteam^S0B970J8V9D|@manufacturing.team>';

        List<Object> blocks = new List<Object>{
            new Map<String, Object>{
                'type' => 'header',
                'text' => new Map<String, Object>{'type'=>'plain_text','text'=>'Opportunity: ' + opportunityName,'emoji'=>true}
            },
            new Map<String, Object>{
                'type'   => 'section',
                'fields' => new List<Object>{
                    new Map<String, Object>{'type'=>'mrkdwn','text'=>'*Account:*\n' + accountName}
                }
            },
            new Map<String, Object>{'type' => 'divider'},
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => groupMention + ' — collaboration channel for this opportunity.'
                }
            }
        };

        Map<String, Object> body = SlackApiClient.post(token, 'https://slack.com/api/chat.postMessage', new Map<String, Object>{
            'channel' => channelId,
            'blocks'  => blocks,
            'text'    => 'Opportunity: ' + opportunityName
        });
        SlackApiClient.requireOk(body, 'chat.postMessage');
    }

    private static String buildOpportunityChannelName(String accountName, String opportunityName) {
        String combined = accountName + ' ' + opportunityName;
        String name = 'opp-' + combined.toLowerCase();
        name = name.replaceAll('[^a-z0-9\\-]', '-').replaceAll('-{2,}', '-').replaceAll('-$', '');
        return name.length() > 80 ? name.substring(0, 80) : name;
    }

    public class OpportunityRequest {
        @InvocableVariable(label='Opportunity Id' required=true) public Id opportunityId;
        @InvocableVariable(label='Opportunity Name' required=false) public String opportunityName;
        @InvocableVariable(label='Account Name' required=false) public String accountName;
    }
}
