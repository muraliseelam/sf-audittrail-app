// Emails the reviewer user a link to set its password. Run as its own
// transaction, after create-reviewer-user.apex has committed the user.
// No password passes through this script or the terminal.
User reviewer = [SELECT Id FROM User WHERE Username = '__USERNAME__' LIMIT 1];
System.resetPassword(reviewer.Id, true);
