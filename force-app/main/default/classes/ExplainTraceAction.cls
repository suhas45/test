/**
 * Returns the real step log for the current chat so the agent can show
 * the visitor what actually ran, not a made-up explanation.
 */
public without sharing class ExplainTraceAction {
    public class TraceStep {
        @AuraEnabled public Integer order;
        @AuraEnabled public String subagent;
        @AuraEnabled public String action;
        @AuraEnabled public String summary;
        @AuraEnabled public String source;
        @AuraEnabled public String timeLabel;
    }

    public class Trace {
        @AuraEnabled public List<TraceStep> steps;
        @AuraEnabled public String note;
    }

    public class Request {
        @InvocableVariable(label='Session Id' description='Messaging session id.' required=true)
        public String sessionId;
    }

    public class Response {
        @InvocableVariable(label='Trace' description='Steps that ran in this chat, oldest first.')
        public Trace trace;
        @InvocableVariable(label='Summary' description='Plain-text list of the steps for the agent to reference.')
        public String summary;
    }

    @InvocableMethod(label='Website: Explain Steps' description='Returns the actions that ran in this chat so far, from the step log.')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            out.add(build(r.sessionId));
        }
        return out;
    }

    private static Response build(String sessionId) {
        List<Agent_Step_Log__c> rows = String.isBlank(sessionId)
            ? new List<Agent_Step_Log__c>()
            : [
                SELECT Subagent__c, Action__c, Summary__c, Data_Source__c, CreatedDate
                FROM Agent_Step_Log__c
                WHERE Session_Id__c = :sessionId
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 6
            ];

        Trace t = new Trace();
        t.steps = new List<TraceStep>();
        List<String> lines = new List<String>();
        for (Integer i = rows.size() - 1; i >= 0; i--) {
            Agent_Step_Log__c row = rows[i];
            TraceStep s = new TraceStep();
            s.order = t.steps.size() + 1;
            s.subagent = row.Subagent__c;
            s.action = row.Action__c;
            s.summary = row.Summary__c;
            s.source = row.Data_Source__c;
            s.timeLabel = row.CreatedDate.format('HH:mm:ss');
            t.steps.add(s);
            lines.add(s.order + '. ' + s.subagent + ' / ' + s.action + ': ' + s.summary);
        }
        t.note = 'This is the live step log for this chat, written by each action as it ran. Plain answers and routing are not logged.';

        Response res = new Response();
        res.trace = t;
        res.summary = lines.isEmpty() ? 'No actions have run in this chat yet.' : String.join(lines, '\n');
        return res;
    }
}