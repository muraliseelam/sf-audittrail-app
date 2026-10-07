// Writes Setup Audit Trail history so the reviewer's searches return rows.
//
// Creates, relabels and then deletes 60 permission sets in one transaction.
// Creation alone writes one audit row per permission set (65 inserts gave 65
// rows on 2026-09-13), all sharing a timestamp, so the app's 50-row page
// boundary falls inside a same-timestamp block - the case its cursor exists
// for. setup.sh counts the rows that actually landed rather than assuming. The permission sets are deleted again, so the org is left with no extra
// metadata; the audit rows stay, because Setup Audit Trail is append-only.
String stamp = String.valueOf(Datetime.now().getTime());
List<PermissionSet> seeds = new List<PermissionSet>();
for (Integer i = 1; i <= 60; i++) {
    String n = String.valueOf(i).leftPad(2, '0');
    seeds.add(new PermissionSet(Name = 'ATE_Seed_' + stamp + '_' + n, Label = 'ATE Seed ' + n));
}
insert seeds;
for (PermissionSet ps : seeds) {
    ps.Label = ps.Label + ' (relabelled)';
}
update seeds;
delete seeds;
