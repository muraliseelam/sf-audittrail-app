// Creates the non-administrator test user the security reviewer logs in as,
// and gives it exactly the two grants a subscriber's administrator must give.
//
// Run by setup.sh, which fills in the two values below. Safe to re-run:
// every step looks for what it would create before creating it.
String reviewerEmail = '__EMAIL__';
String reviewerUsername = '__USERNAME__';

// Grant 2 of 2. Salesforce strips ViewSetup and ViewRoles from the packaged
// permission set on install, so a subscriber must grant them from its own org.
// This permission set is that subscriber-side grant. LightningExperienceUser is
// included because the app is a Lightning tab and the reviewer is on a minimal
// profile.
List<PermissionSet> existingViewSetup = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'ATE_Reviewer_View_Setup' AND NamespacePrefix = NULL
];
PermissionSet viewSetup;
if (existingViewSetup.isEmpty()) {
    viewSetup = new PermissionSet(
        Name = 'ATE_Reviewer_View_Setup',
        Label = 'ATE Reviewer - View Setup',
        Description = 'Subscriber-side grant of View Setup and Configuration for Audit Trail Explorer. The managed package cannot grant it.',
        PermissionsViewSetup = true,
        PermissionsViewRoles = true,
        PermissionsLightningExperienceUser = true
    );
    insert viewSetup;
} else {
    viewSetup = existingViewSetup[0];
}

// Grant 1 of 2: the packaged permission set (app, tab, Apex class access).
PermissionSet viewer = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'Audit_Trail_Viewer' AND NamespacePrefix = 'atexplorer'
    LIMIT 1
];

List<User> existingUsers = [SELECT Id FROM User WHERE Username = :reviewerUsername];
User reviewer;
if (existingUsers.isEmpty()) {
    Profile minimum = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
    User admin = [
        SELECT TimeZoneSidKey, LocaleSidKey, LanguageLocaleKey, EmailEncodingKey
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];
    reviewer = new User(
        FirstName = 'Security',
        LastName = 'Reviewer',
        Alias = 'atereviw',
        Email = reviewerEmail,
        Username = reviewerUsername,
        ProfileId = minimum.Id,
        TimeZoneSidKey = admin.TimeZoneSidKey,
        LocaleSidKey = admin.LocaleSidKey,
        LanguageLocaleKey = admin.LanguageLocaleKey,
        EmailEncodingKey = admin.EmailEncodingKey
    );
    insert reviewer;
} else {
    reviewer = existingUsers[0];
}

Set<Id> alreadyAssigned = new Set<Id>();
for (PermissionSetAssignment psa : [
    SELECT PermissionSetId
    FROM PermissionSetAssignment
    WHERE AssigneeId = :reviewer.Id
]) {
    alreadyAssigned.add(psa.PermissionSetId);
}
List<PermissionSetAssignment> toAssign = new List<PermissionSetAssignment>();
for (Id psId : new List<Id>{ viewer.Id, viewSetup.Id }) {
    if (!alreadyAssigned.contains(psId)) {
        toAssign.add(new PermissionSetAssignment(AssigneeId = reviewer.Id, PermissionSetId = psId));
    }
}
insert toAssign;

System.debug(LoggingLevel.ERROR, 'ATE_REVIEWER_USER_ID=' + reviewer.Id);
