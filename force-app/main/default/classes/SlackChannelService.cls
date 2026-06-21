public class SlackChannelService {

    private static final String DEFAULT_USER_GROUP_ID = 'S0B970J8V9D';
    private static final String DEFAULT_USER_GROUP_HANDLE = 'manufacturing.team';
    private static final String VANCE_USER_NAME = 'vance';

    private static final List<String> DEPARTMENT_LABELS = new List<String>{
        'Design', 'Sales', 'SCM', 'Manufacturing'
    };

    private static final List<String> ORDER_TEAM_LABELS = new List<String>{
        'Logistics', 'Quality Assurance', 'Finance'
    };

    @InvocableMethod(label='Create Slack Channel' description='Creates a Slack channel for an Order')
    public static void createChannel(List<Request> requests) {
        for (Request req : requests) {
            createChannelFuture(
                req.orderNumber,
                req.accountName,
                req.status,
                req.totalAmount,
                req.effectiveDate != null ? String.valueOf(req.effectiveDate) : null,
                req.description,
                req.opportunityId,
                req.logisticsTask,
                req.qaTask,
                req.financeTask
            );
        }
    }

    public static void createListForOpportunity(Id opportunityId) {
        List<SObject> opps = Database.query(
            'SELECT Slack_Channel_Id__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1'
        );
        if (opps.isEmpty() || String.isBlank((String) opps[0].get('Slack_Channel_Id__c'))) {
            throw new SlackApiClient.SlackException('Slack channel not yet created for this opportunity');
        }
        String channelId = (String) opps[0].get('Slack_Channel_Id__c');
        createOpportunityListAsync(opportunityId, channelId);
    }

    @future(callout=true)
    private static void createOpportunityListAsync(Id opportunityId, String channelId) {
        try {
            String token = SlackApiClient.loadConfig().botToken;
            if (!hasRegisteredList(opportunityId.to15())) {
                Map<String, String> nextActions = loadNextActions(opportunityId);
                List<String> memberIds = getUserGroupMembers(token, DEFAULT_USER_GROUP_ID);

                List<SObject> opps = Database.query(
                    'SELECT Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1'
                );
                String oppName = opps.isEmpty() ? opportunityId.to15() : opps[0].get('Name').toString();

                String vanceUserId = findUserByName(token, VANCE_USER_NAME);

                try {
                    createNextActionList(token, channelId, oppName, nextActions, vanceUserId);
                } catch (Exception listEx) {
                    System.debug(LoggingLevel.ERROR, 'Slack list error: ' + listEx.getMessage());
                    postListFailureMessage(token, channelId, oppName, listEx.getMessage());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SlackChannelService.createOpportunityListAsync error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }


    @future(callout=true)
    @TestVisible
    private static void createChannelFuture(
        String orderNumber,
        String accountName,
        String status,
        Decimal totalAmount,
        String effectiveDate,
        String description,
        Id opportunityId,
        String logisticsTask,
        String qaTask,
        String financeTask
    ) {
        try {
            String token = SlackApiClient.loadConfig().botToken;
            String channelName = buildChannelName(orderNumber);
            String channelId = resolveOrCreateChannel(token, channelName);

            List<String> memberIds = getUserGroupMembers(token, DEFAULT_USER_GROUP_ID);
            if (!memberIds.isEmpty()) {
                inviteUsersToChannel(token, channelId, memberIds);
            }

            String vanceUserId = null;
            try {
                vanceUserId = findUserByName(token, VANCE_USER_NAME);
                if (String.isNotBlank(vanceUserId)) {
                    inviteUsersToChannel(token, channelId, new List<String>{ vanceUserId });
                }
            } catch (Exception vanceEx) {
                System.debug(LoggingLevel.WARN, 'Could not find or add Vance user: ' + vanceEx.getMessage());
            }

            sendOrderMessage(token, channelId, orderNumber, accountName, status, totalAmount, effectiveDate, description, logisticsTask, qaTask, financeTask);

            if (!hasRegisteredList(orderNumber)) {
                Map<String, String> orderTasks = buildOrderTaskMap(logisticsTask, qaTask, financeTask);
                try {
                    createOrderActionList(token, channelId, orderNumber, orderTasks, vanceUserId);
                } catch (Exception listEx) {
                    System.debug(LoggingLevel.ERROR, 'Slack list error: ' + listEx.getMessage());
                    postListFailureMessage(token, channelId, orderNumber, listEx.getMessage());
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SlackChannelService error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    @TestVisible
    private static Map<String, String> loadNextActions(Id opportunityId) {
        Map<String, String> actions = defaultNextActions();
        if (opportunityId == null) {
            return actions;
        }

        List<SObject> opps = Database.query(
            'SELECT toLabel(Design_Next_Action__c) DesignTask,' +
            '       toLabel(Sales_Next_Action__c) SalesTask,' +
            '       toLabel(SCM_Next_Action__c) ScmTask,' +
            '       toLabel(Manufacturing_Next_Action__c) MfgTask' +
            '  FROM Opportunity' +
            ' WHERE Id = :opportunityId' +
            ' LIMIT 1'
        );
        if (opps.isEmpty()) {
            return actions;
        }

        SObject opp = opps[0];
        putTaskIfPresent(actions, 'Design', opp.get('DesignTask'));
        putTaskIfPresent(actions, 'Sales', opp.get('SalesTask'));
        putTaskIfPresent(actions, 'SCM', opp.get('ScmTask'));
        putTaskIfPresent(actions, 'Manufacturing', opp.get('MfgTask'));
        return actions;
    }

    private static void putTaskIfPresent(Map<String, String> actions, String department, Object value) {
        String label = taskLabel(value);
        if (String.isNotBlank(label)) {
            actions.put(department, label);
        }
    }

    private static Map<String, String> defaultNextActions() {
        return new Map<String, String>{
            'Design' => 'No design task assigned',
            'Sales' => 'No sales task assigned',
            'SCM' => 'No SCM task assigned',
            'Manufacturing' => 'No manufacturing task assigned'
        };
    }

    private static String taskLabel(Object value) {
        if (value == null) {
            return null;
        }
        String label = String.valueOf(value);
        return String.isBlank(label) ? null : label;
    }

    @TestVisible
    private static void createNextActionList(
        String token,
        String channelId,
        String orderNumber,
        Map<String, String> nextActions,
        String vanceUserId
    ) {
        ListSchema schema = createSlackList(token, 'Next Actions - Order ' + orderNumber);
        shareListWithChannel(token, schema.listId, channelId);

        SlackTaskFollowupService.ListRegistration registration = new SlackTaskFollowupService.ListRegistration();
        registration.listId = schema.listId;
        registration.channelId = channelId;
        registration.orderNumber = orderNumber;
        registration.progressColumnId = schema.progressColumnId;
        registration.dueDateColumnId = schema.dueDateColumnId;

        for (String department : DEPARTMENT_LABELS) {
            String actionLabel = nextActions.containsKey(department)
                ? nextActions.get(department)
                : 'Not Started';
            String itemId = createListItem(
                token,
                schema,
                department + ': ' + actionLabel,
                vanceUserId
            );

            SlackTaskFollowupService.TaskRegistration task = new SlackTaskFollowupService.TaskRegistration();
            task.itemId = itemId;
            task.department = department;
            task.taskLabel = actionLabel;
            task.assigneeId = vanceUserId;
            registration.tasks.add(task);
        }

        SlackTaskFollowupService.registerList(registration);
        postListCreatedMessage(token, channelId, orderNumber);
    }

    @TestVisible
    private static ListSchema createSlackList(String token, String listName) {
        Map<String, Object> body = SlackApiClient.post(token, 'https://slack.com/api/slackLists.create', new Map<String, Object>{
            'name' => listName,
            'todo_mode' => true,
            'schema' => new List<Object>{
                new Map<String, Object>{
                    'key' => 'title',
                    'name' => 'Name',
                    'type' => 'text',
                    'is_primary_column' => true
                },
                new Map<String, Object>{
                    'key' => 'progress',
                    'name' => 'Progress',
                    'type' => 'text'
                }
            }
        });
        SlackApiClient.requireOk(body, 'slackLists.create');

        ListSchema schema = new ListSchema();
        schema.listId = (String) body.get('list_id');
        parseListSchema(schema, (Map<String, Object>) body.get('list_metadata'));
        if (String.isBlank(schema.listId) || String.isBlank(schema.nameColumnId)) {
            throw new SlackApiClient.SlackException('slackLists.create returned incomplete list metadata');
        }
        return schema;
    }

    @TestVisible
    private static void parseListSchema(ListSchema schema, Map<String, Object> listMetadata) {
        if (listMetadata == null || !listMetadata.containsKey('schema')) {
            return;
        }
        for (Object columnObj : (List<Object>) listMetadata.get('schema')) {
            Map<String, Object> column = (Map<String, Object>) columnObj;
            String columnType = (String) column.get('type');
            String columnId = (String) column.get('id');
            String key = (String) column.get('key');
            Boolean isPrimary = column.get('is_primary_column') == true;

            if (columnType == 'text' && (isPrimary || schema.nameColumnId == null)) {
                schema.nameColumnId = columnId;
            } else if (columnType == 'todo_assignee' || key == 'todo_assignee') {
                schema.assigneeColumnId = columnId;
            } else if (columnType == 'todo_due_date' || key == 'todo_due_date') {
                schema.dueDateColumnId = columnId;
            } else if (key == 'progress') {
                schema.progressColumnId = columnId;
            }
        }
    }

    @TestVisible
    private static void shareListWithChannel(String token, String listId, String channelId) {
        Map<String, Object> body = SlackApiClient.post(token, 'https://slack.com/api/slackLists.access.set', new Map<String, Object>{
            'list_id' => listId,
            'access_level' => 'write',
            'channel_ids' => new List<String>{ channelId }
        });
        SlackApiClient.requireOk(body, 'slackLists.access.set (channel)');
    }

    private static void postListFailureMessage(String token, String channelId, String orderNumber, String errorMessage) {
        SlackApiClient.post(token, 'https://slack.com/api/chat.postMessage', new Map<String, Object>{
            'channel' => channelId,
            'text' => 'Could not create the Next Actions list for order ' + orderNumber + ': ' + errorMessage
        });
    }

    @TestVisible
    private static String createListItem(
        String token,
        ListSchema schema,
        String taskName,
        String assigneeUserId
    ) {
        List<Object> initialFields = new List<Object>();
        if (String.isNotBlank(schema.nameColumnId)) {
            initialFields.add(new Map<String, Object>{
                'column_id' => schema.nameColumnId,
                'rich_text' => SlackApiClient.richTextField(taskName)
            });
        }
        if (String.isNotBlank(schema.assigneeColumnId) && String.isNotBlank(assigneeUserId)) {
            initialFields.add(new Map<String, Object>{
                'column_id' => schema.assigneeColumnId,
                'user' => new List<String>{ assigneeUserId }
            });
        }
        if (String.isNotBlank(schema.progressColumnId)) {
            initialFields.add(new Map<String, Object>{
                'column_id' => schema.progressColumnId,
                'rich_text' => SlackApiClient.richTextField('0%')
            });
        }
        if (String.isNotBlank(schema.dueDateColumnId)) {
            initialFields.add(new Map<String, Object>{
                'column_id' => schema.dueDateColumnId,
                'date' => new List<String>{ String.valueOf(Date.today().addDays(14)) }
            });
        }

        Map<String, Object> body = SlackApiClient.post(token, 'https://slack.com/api/slackLists.items.create', new Map<String, Object>{
            'list_id' => schema.listId,
            'initial_fields' => initialFields
        });
        SlackApiClient.requireOk(body, 'slackLists.items.create');
        Map<String, Object> item = (Map<String, Object>) body.get('item');
        return item != null ? (String) item.get('id') : null;
    }

    private static void postListCreatedMessage(String token, String channelId, String orderNumber) {
        Map<String, Object> body = SlackApiClient.post(token, 'https://slack.com/api/chat.postMessage', new Map<String, Object>{
            'channel' => channelId,
            'text' => 'A Next Actions list was created for order ' + orderNumber
                + '. Daily check-ins will be posted here until each task due date — use the progress dropdown to update the Progress column.'
        });
        SlackApiClient.requireOk(body, 'chat.postMessage (list notice)');
    }

    public static String resolveOrCreateChannelPublic(String token, String channelName) {
        return resolveOrCreateChannel(token, channelName);
    }

    private static String resolveOrCreateChannel(String token, String channelName) {
        Map<String, Object> body = SlackApiClient.post(token, 'https://slack.com/api/conversations.create', new Map<String, Object>{
            'name' => channelName,
            'is_private' => false
        });
        if (body.get('ok') == true) {
            return (String) ((Map<String, Object>) body.get('channel')).get('id');
        }
        if ('name_taken'.equals(body.get('error'))) {
            return findChannelByName(token, channelName);
        }
        SlackApiClient.requireOk(body, 'conversations.create');
        return null;
    }

    @TestVisible
    private static String findChannelByName(String token, String channelName) {
        String cursor;
        do {
            String endpoint = 'https://slack.com/api/conversations.list?types=public_channel&limit=200'
                + (String.isNotBlank(cursor) ? '&cursor=' + EncodingUtil.urlEncode(cursor, 'UTF-8') : '');
            Map<String, Object> body = SlackApiClient.get(token, endpoint);
            SlackApiClient.requireOk(body, 'conversations.list');
            for (Object channelObj : (List<Object>) body.get('channels')) {
                Map<String, Object> channel = (Map<String, Object>) channelObj;
                if (channelName.equals(channel.get('name'))) {
                    return (String) channel.get('id');
                }
            }
            Map<String, Object> responseMetadata = (Map<String, Object>) body.get('response_metadata');
            cursor = responseMetadata != null ? (String) responseMetadata.get('next_cursor') : null;
        } while (String.isNotBlank(cursor));
        throw new SlackApiClient.SlackException('Channel not found: ' + channelName);
    }

    private static Boolean hasRegisteredList(String orderNumber) {
        return ![SELECT Id FROM Slack_Order_List__c WHERE Order_Number__c = :orderNumber LIMIT 1].isEmpty();
    }

    public static List<String> getUserGroupMembersPublic(String token, String userGroupId) {
        return getUserGroupMembers(token, userGroupId);
    }

    private static List<String> getUserGroupMembers(String token, String userGroupId) {
        Map<String, Object> body = SlackApiClient.get(
            token,
            'https://slack.com/api/usergroups.users.list?usergroup=' + userGroupId
        );
        SlackApiClient.requireOk(body, 'usergroups.users.list');

        List<String> memberIds = new List<String>();
        for (Object userId : (List<Object>) body.get('users')) {
            memberIds.add((String) userId);
        }
        return memberIds;
    }

    private static String findUserByName(String token, String userName) {
        String cursor;
        do {
            String endpoint = 'https://slack.com/api/users.list?limit=200'
                + (String.isNotBlank(cursor) ? '&cursor=' + EncodingUtil.urlEncode(cursor, 'UTF-8') : '');
            Map<String, Object> body = SlackApiClient.get(token, endpoint);
            SlackApiClient.requireOk(body, 'users.list');
            for (Object userObj : (List<Object>) body.get('members')) {
                Map<String, Object> user = (Map<String, Object>) userObj;
                String name = (String) user.get('name');
                if (userName.equalsIgnoreCase(name)) {
                    return (String) user.get('id');
                }
            }
            Map<String, Object> responseMetadata = (Map<String, Object>) body.get('response_metadata');
            cursor = responseMetadata != null ? (String) responseMetadata.get('next_cursor') : null;
        } while (String.isNotBlank(cursor));
        return null;
    }

    public static void inviteUsersToChannelPublic(String token, String channelId, List<String> userIds) {
        inviteUsersToChannel(token, channelId, userIds);
    }

    public static String findUserByNamePublic(String token, String userName) {
        return findUserByName(token, userName);
    }

    private static void inviteUsersToChannel(String token, String channelId, List<String> userIds) {
        Map<String, Object> body = SlackApiClient.post(token, 'https://slack.com/api/conversations.invite', new Map<String, Object>{
            'channel' => channelId,
            'users' => String.join(userIds, ',')
        });
        if (body.get('ok') != true) {
            String error = (String) body.get('error');
            if (error != 'already_in_channel') {
                throw new SlackApiClient.SlackException('conversations.invite failed: ' + error);
            }
        }
    }

    @TestVisible
    private static Map<String, String> buildOrderTaskMap(String logi, String qa, String fin) {
        return new Map<String, String>{
            'Logistics'         => String.isNotBlank(logi) ? logi : 'No logistics task assigned',
            'Quality Assurance' => String.isNotBlank(qa)   ? qa   : 'No QA task assigned',
            'Finance'           => String.isNotBlank(fin)  ? fin  : 'No finance task assigned'
        };
    }

    @TestVisible
    private static void createOrderActionList(
        String token,
        String channelId,
        String orderNumber,
        Map<String, String> orderTasks,
        String vanceUserId
    ) {
        ListSchema schema = createSlackList(token, 'Order Tasks - ' + orderNumber);
        shareListWithChannel(token, schema.listId, channelId);

        SlackTaskFollowupService.ListRegistration registration = new SlackTaskFollowupService.ListRegistration();
        registration.listId = schema.listId;
        registration.channelId = channelId;
        registration.orderNumber = orderNumber;
        registration.progressColumnId = schema.progressColumnId;
        registration.dueDateColumnId = schema.dueDateColumnId;

        for (String team : ORDER_TEAM_LABELS) {
            String taskLabel = orderTasks.containsKey(team)
                ? orderTasks.get(team)
                : 'Not Started';
            String itemId = createListItem(
                token,
                schema,
                team + ': ' + taskLabel,
                vanceUserId
            );

            SlackTaskFollowupService.TaskRegistration task = new SlackTaskFollowupService.TaskRegistration();
            task.itemId = itemId;
            task.department = team;
            task.taskLabel = taskLabel;
            task.assigneeId = vanceUserId;
            registration.tasks.add(task);
        }

        SlackTaskFollowupService.registerList(registration);
        postListCreatedMessage(token, channelId, orderNumber);
    }

    private static void sendOrderMessage(
        String token, String channelId,
        String orderNumber, String accountName, String status,
        Decimal totalAmount, String effectiveDate, String description,
        String logisticsTask, String qaTask, String financeTask
    ) {
        String groupMention  = '<!subteam^' + DEFAULT_USER_GROUP_ID + '|@' + DEFAULT_USER_GROUP_HANDLE + '>';
        String totalDisplay  = totalAmount != null ? '$' + totalAmount.setScale(2).toPlainString() : 'N/A';
        String dateDisplay   = String.isNotBlank(effectiveDate) ? effectiveDate : 'N/A';
        String accountDisplay = String.isNotBlank(accountName) ? accountName : 'N/A';
        String descDisplay   = String.isNotBlank(description)  ? description  : '_No description provided_';

        String taskText = '*Team Task Assignments:*\n' +
            '• Logistics: ' + (String.isNotBlank(logisticsTask) ? logisticsTask : 'No task assigned') + '\n' +
            '• Quality Assurance: ' + (String.isNotBlank(qaTask) ? qaTask : 'No task assigned') + '\n' +
            '• Finance: ' + (String.isNotBlank(financeTask) ? financeTask : 'No task assigned');

        List<Object> blocks = new List<Object>{
            new Map<String, Object>{
                'type' => 'header',
                'text' => new Map<String, Object>{'type'=>'plain_text','text'=>'New Order: ' + orderNumber,'emoji'=>true}
            },
            new Map<String, Object>{
                'type'   => 'section',
                'fields' => new List<Object>{
                    new Map<String, Object>{'type'=>'mrkdwn','text'=>'*Account:*\n' + accountDisplay},
                    new Map<String, Object>{'type'=>'mrkdwn','text'=>'*Status:*\n' + status},
                    new Map<String, Object>{'type'=>'mrkdwn','text'=>'*Total Amount:*\n' + totalDisplay},
                    new Map<String, Object>{'type'=>'mrkdwn','text'=>'*Effective Date:*\n' + dateDisplay}
                }
            },
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{'type'=>'mrkdwn','text'=>'*Description:*\n' + descDisplay}
            },
            new Map<String, Object>{'type' => 'divider'},
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{'type'=>'mrkdwn','text'=>taskText}
            },
            new Map<String, Object>{'type' => 'divider'},
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => groupMention + ' — a new draft order has been created and needs your attention.'
                }
            }
        };

        Map<String, Object> body = SlackApiClient.post(token, 'https://slack.com/api/chat.postMessage', new Map<String, Object>{
            'channel' => channelId,
            'blocks'  => blocks,
            'text'    => 'New Draft Order: ' + orderNumber
        });
        SlackApiClient.requireOk(body, 'chat.postMessage');
    }

    private static String buildChannelName(String orderNumber) {
        String name = 'order-' + orderNumber.toLowerCase();
        name = name.replaceAll('[^a-z0-9\\-]', '-').replaceAll('-{2,}', '-');
        return name.length() > 80 ? name.substring(0, 80) : name;
    }


    public class ListSchema {
        public String listId;
        public String nameColumnId;
        public String assigneeColumnId;
        public String dueDateColumnId;
        public String progressColumnId;
    }

    public class Request {
        @InvocableVariable(label='Order Number'   required=true)  public String  orderNumber;
        @InvocableVariable(label='Account Name'   required=false) public String  accountName;
        @InvocableVariable(label='Status'         required=false) public String  status;
        @InvocableVariable(label='Total Amount'   required=false) public Decimal totalAmount;
        @InvocableVariable(label='Effective Date' required=false) public Date    effectiveDate;
        @InvocableVariable(label='Description'    required=false) public String  description;
        @InvocableVariable(label='Opportunity Id' required=false) public Id      opportunityId;
        @InvocableVariable(label='Logistics Task' required=false) public String  logisticsTask;
        @InvocableVariable(label='QA Task'        required=false) public String  qaTask;
        @InvocableVariable(label='Finance Task'   required=false) public String  financeTask;
    }

}