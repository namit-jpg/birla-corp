/**
 * Async Slack notification service for the EPC PM Platform.
 *
 * Setup (one-time, per org):
 *  1. Deploy this package (creates Slack_Settings__c custom setting + Remote Site).
 *  2. In Setup > Custom Settings > Slack Settings, click "Manage", then "New" (org default).
 *     Paste your Slack bot token (xoxb-...) into the Bot Token field.
 *  3. The bot must be a member of any project channel it should post to.
 *
 * Channel naming convention: project record Name lowercased (e.g. PRJ-00049 → prj-00049).
 */
public with sharing class SlackService {

    private static final String API_URL = 'https://slack.com/api/chat.postMessage';

    @future(callout=true)
    public static void postDelayAlertAsync(
            String channel,
            String projectName,
            String criticalJson,
            String highJson) {

        Slack_Settings__c cfg = Slack_Settings__c.getOrgDefaults();
        if (cfg == null || String.isBlank(cfg.Bot_Token__c)) {
            System.debug('SlackService: no bot token configured in Slack_Settings__c — skipping post.');
            return;
        }

        String text = buildText(projectName, criticalJson, highJson);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json; charset=utf-8');
        req.setHeader('Authorization', 'Bearer ' + cfg.Bot_Token__c);
        req.setBody(JSON.serialize(new Map<String, Object>{
            'channel' => channel,
            'text'    => text,
            'mrkdwn'  => true
        }));
        req.setTimeout(10000);

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug('SlackService: unexpected HTTP ' + res.getStatusCode() + ' — ' + res.getBody());
            }
        } catch (Exception ex) {
            System.debug('SlackService callout failed: ' + ex.getMessage());
        }
    }

    // ── message builder ─────────────────────────────────────────────────────────

    private static String buildText(String projectName, String criticalJson, String highJson) {
        List<Object> critItems = (List<Object>) JSON.deserializeUntyped(criticalJson);
        List<Object> highItems = (List<Object>) JSON.deserializeUntyped(highJson);

        Date today = Date.today();
        String[] months = new String[]{
            'Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'
        };
        String dateStr = today.day() + ' ' + months[today.month() - 1] + ' ' + today.year();

        String nl  = '\n';
        String msg = ':rotating_light: *PROJECT DELAY ALERT — ' + projectName + '*' + nl;
        msg += '*Report Date:* ' + dateStr + '   |   *Source:* Salesforce EPC PM System' + nl;
        msg += nl;

        msg += '*SUMMARY*' + nl;
        msg += ':red_circle: *' + critItems.size() + ' Critical* — directly threatening project completion date' + nl;
        msg += ':large_orange_circle: *' + highItems.size() + ' High Risk* — limited time buffer remaining' + nl;
        msg += nl;

        if (!critItems.isEmpty()) {
            msg += ':red_circle: *CRITICAL — Immediate Escalation Required*' + nl;
            msg += '_These activities are on the critical path. Every day of further delay extends the project end date._' + nl;
            msg += nl;
            for (Object raw : critItems) {
                Map<String, Object> item = (Map<String, Object>) raw;
                msg += '• *' + item.get('code') + '* ' + item.get('name')
                     + '  —  ' + item.get('pct') + '% complete' + nl;
            }
            msg += nl;
        }

        if (!highItems.isEmpty()) {
            msg += ':large_orange_circle: *HIGH RISK — Urgent Attention Needed*' + nl;
            msg += '_Time buffer is running low. Escalate before these reach the critical path._' + nl;
            msg += nl;
            for (Object raw : highItems) {
                Map<String, Object> item = (Map<String, Object>) raw;
                msg += '• *' + item.get('code') + '* ' + item.get('name')
                     + '  —  ' + item.get('pct') + '% complete' + nl;
            }
            msg += nl;
        }

        msg += '_Generated automatically by the Birla Corp EPC PM Platform._';
        return msg;
    }
}
