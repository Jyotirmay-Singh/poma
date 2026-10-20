PRAGMA user_version = 2;
CREATE TABLE notification_state (id INTEGER PRIMARY KEY CHECK(id = 1), value TEXT NOT NULL);
CREATE TABLE notification_receipts (key TEXT PRIMARY KEY, created_at INTEGER NOT NULL);
INSERT INTO notification_state VALUES (1, '{"enabled":true,"permissionRequested":true,"serial":7,"nextNotificationId":8,"current":null,"previous":{"runId":"old-alert","generation":7,"notificationId":7,"phase":"focus","segment":1,"deadlineUtcMicros":1792454400000000,"elapsedDeadlineMicros":1000000,"maximumRemainingMicros":1000000,"bootCount":4},"retiredIds":[7]}');
INSERT INTO notification_receipts VALUES ('action:old-alert:7:open',1792454400000);
