#!/usr/bin/env bash
# Prepares a fresh Developer Edition org as the AppExchange security reviewer's
# test environment. See docs/SUBMISSION-RUNBOOK.md, Phase 1.
#
# Usage:
#   scripts/review-org/setup.sh <org-alias> <reviewer-email> [reviewer-username]
#
# <org-alias>       An org already authorised with `sf org login web --alias ...`.
#                   Must be a Developer Edition org with no other package installed.
# <reviewer-email>  Mailbox that receives the reviewer user's set-password email.
#                   Use one you control; you then pass the credentials to
#                   Salesforce in the submission wizard.
#
# Safe to re-run: each step checks before it creates.
set -euo pipefail

PACKAGE_VERSION_ID=04thm000002OtQPAA0
TEST_CLASSES=(
    atexplorer.AuditPermissionServiceTest
    atexplorer.AuditQueryControllerTest
    atexplorer.AuditQueryServiceTest
    atexplorer.SetupAuditTrailProviderTest
)

if [[ $# -lt 2 ]]; then
    sed -n '2,15p' "$0"
    exit 2
fi
ORG=$1
REVIEWER_EMAIL=$2
REVIEWER_USERNAME=${3:-ate.reviewer.$(date +%Y%m%d%H%M)@atexplorer.review}

HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/out"
mkdir -p "$OUT"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Runs a SOQL query and prints the records array as JSON.
query() {
    local tooling=()
    [[ ${2:-} == tooling ]] && tooling=(--use-tooling-api)
    sf data query --target-org "$ORG" --query "$1" "${tooling[@]}" --json |
        node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);if(j.status!==0){console.error(j.message);process.exit(1)}console.log(JSON.stringify(j.result.records))})'
}
# Evaluates a JS expression against the JSON on stdin, bound to `r`.
js() { node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const r=JSON.parse(s);console.log($1)})"; }

step "Preflight: org must be a Developer Edition org, not a sandbox"
ORGINFO=$(query "SELECT Id, OrganizationType, IsSandbox FROM Organization")
ORG_ID=$(echo "$ORGINFO" | js 'r[0].Id')
ORG_TYPE=$(echo "$ORGINFO" | js 'r[0].OrganizationType')
IS_SANDBOX=$(echo "$ORGINFO" | js 'r[0].IsSandbox')
echo "Org $ORG_ID: $ORG_TYPE, sandbox=$IS_SANDBOX"
[[ $ORG_TYPE == "Developer Edition" ]] || fail "expected a Developer Edition org, got '$ORG_TYPE'"
[[ $IS_SANDBOX == "false" ]] || fail "org is a sandbox"

step "Preflight: no package other than atexplorer may be installed"
INSTALLED=$(query "SELECT SubscriberPackage.NamespacePrefix, SubscriberPackageVersionId FROM InstalledSubscriberPackage" tooling)
OTHERS=$(echo "$INSTALLED" | js 'r.map(x=>x.SubscriberPackage.NamespacePrefix).filter(n=>n!=="atexplorer").join(",")')
[[ -z $OTHERS ]] || fail "other packages installed: $OTHERS. Use an org that contains only this package."
OURS=$(echo "$INSTALLED" | js 'r.filter(x=>x.SubscriberPackage.NamespacePrefix==="atexplorer").map(x=>x.SubscriberPackageVersionId).join(",")')

if [[ -z $OURS ]]; then
    step "Install $PACKAGE_VERSION_ID"
    sf package install --target-org "$ORG" --package "$PACKAGE_VERSION_ID" --wait 30 --no-prompt
else
    echo "atexplorer already installed: $OURS"
    [[ $OURS == "$PACKAGE_VERSION_ID"* ]] || fail "installed version $OURS is not $PACKAGE_VERSION_ID"
fi

step "Confirm the install-time strip: packaged permission set must NOT grant ViewSetup"
STRIP=$(query "SELECT PermissionsViewSetup, PermissionsViewRoles FROM PermissionSet WHERE Name = 'Audit_Trail_Viewer' AND NamespacePrefix = 'atexplorer'")
echo "$STRIP"
[[ $(echo "$STRIP" | js 'r.length === 1 && !r[0].PermissionsViewSetup') == true ]] ||
    fail "expected atexplorer__Audit_Trail_Viewer with PermissionsViewSetup=false"

step "Assign atexplorer__Audit_Trail_Viewer to the administrator"
ADMIN_USERNAME=$(sf org display --target-org "$ORG" --json | js 'r.result.username')
if [[ $(query "SELECT Id FROM PermissionSetAssignment WHERE Assignee.Username = '$ADMIN_USERNAME' AND PermissionSet.Name = 'Audit_Trail_Viewer' AND PermissionSet.NamespacePrefix = 'atexplorer'" | js 'r.length') == 0 ]]; then
    sf org assign permset --target-org "$ORG" --name atexplorer__Audit_Trail_Viewer
fi

step "Create the non-administrator reviewer user ($REVIEWER_USERNAME) with both grants"
sed -e "s|__EMAIL__|$REVIEWER_EMAIL|" -e "s|__USERNAME__|$REVIEWER_USERNAME|" \
    "$HERE/create-reviewer-user.apex" > "$WORK/create.apex"
sf apex run --target-org "$ORG" --file "$WORK/create.apex" > "$WORK/create.log" ||
    { cat "$WORK/create.log"; fail "reviewer user creation failed"; }

step "Verify the reviewer user's effective grants"
REVIEWER=$(query "SELECT Id, Profile.Name, IsActive FROM User WHERE Username = '$REVIEWER_USERNAME'")
REVIEWER_ID=$(echo "$REVIEWER" | js 'r[0].Id')
echo "$REVIEWER"
[[ $(echo "$REVIEWER" | js 'r[0].Profile.Name') == "Minimum Access - Salesforce" ]] || fail "reviewer is not on Minimum Access - Salesforce"
GRANTS=$(query "SELECT PermissionSet.Name, PermissionSet.NamespacePrefix, PermissionSet.PermissionsViewSetup FROM PermissionSetAssignment WHERE AssigneeId = '$REVIEWER_ID'")
echo "$GRANTS"
[[ $(echo "$GRANTS" | js 'r.some(x=>x.PermissionSet.Name==="Audit_Trail_Viewer"&&x.PermissionSet.NamespacePrefix==="atexplorer")') == true ]] ||
    fail "reviewer lacks atexplorer__Audit_Trail_Viewer"
[[ $(echo "$GRANTS" | js 'r.some(x=>x.PermissionSet.PermissionsViewSetup===true)') == true ]] ||
    fail "reviewer has no permission set granting ViewSetup"

step "Seed Setup Audit Trail history"
BEFORE=$(query "SELECT Id FROM SetupAuditTrail WHERE CreatedDate = LAST_N_DAYS:180" | js 'r.length')
sf apex run --target-org "$ORG" --file "$HERE/seed-audit-history.apex" > "$WORK/seed.log" ||
    { cat "$WORK/seed.log"; fail "seeding failed"; }
AUDIT=$(query "SELECT Id, Section FROM SetupAuditTrail WHERE CreatedDate = LAST_N_DAYS:180")
AFTER=$(echo "$AUDIT" | js 'r.length')
SECTIONS=$(echo "$AUDIT" | js '[...new Set(r.map(x=>x.Section).filter(Boolean))].length')
echo "Audit rows: $BEFORE before seeding, $AFTER after, across $SECTIONS distinct sections"
(( AFTER - BEFORE >= 60 )) || fail "seeding wrote $((AFTER - BEFORE)) rows, expected at least 60"

step "Run the packaged Apex tests"
TEST_ARGS=()
for c in "${TEST_CLASSES[@]}"; do TEST_ARGS+=(--class-names "$c"); done
sf apex run test --target-org "$ORG" "${TEST_ARGS[@]}" --wait 20 --result-format json > "$OUT/tests-$ORG_ID.json" || true
TESTS=$(node -e 'const j=require(process.argv[1]);const s=j.result.summary;console.log(`${s.passing}/${s.testsRan} passed, outcome ${s.outcome}, run ${s.testRunId}`)' "$OUT/tests-$ORG_ID.json")
echo "$TESTS"
[[ $TESTS == *"outcome Passed"* ]] || fail "packaged tests did not pass; see $OUT/tests-$ORG_ID.json"

step "Send the reviewer user its set-password email"
sed -e "s|__USERNAME__|$REVIEWER_USERNAME|" "$HERE/reset-reviewer-password.apex" > "$WORK/reset.apex"
sf apex run --target-org "$ORG" --file "$WORK/reset.apex" > "$WORK/reset.log" ||
    { cat "$WORK/reset.log"; fail "password reset email failed"; }

cat > "$OUT/evidence-$ORG_ID.txt" <<SUMMARY
Reviewer org prepared $(date -u +%Y-%m-%dT%H:%M:%SZ)
Org:                 $ORG_ID ($ORG_TYPE, sandbox=$IS_SANDBOX)
Package version:     $PACKAGE_VERSION_ID
Other packages:      none
Packaged permset:    PermissionsViewSetup=false (install-time strip confirmed)
Administrator:       $ADMIN_USERNAME, atexplorer__Audit_Trail_Viewer assigned
Reviewer user:       $REVIEWER_USERNAME ($REVIEWER_ID), Minimum Access - Salesforce,
                     atexplorer__Audit_Trail_Viewer + ATE_Reviewer_View_Setup
Audit rows (180d):   $AFTER across $SECTIONS sections ($BEFORE before seeding)
Packaged Apex tests: $TESTS
SUMMARY

step "Done"
cat "$OUT/evidence-$ORG_ID.txt"
cat <<NEXT

Next, by hand:
  1. Open the set-password email sent to $REVIEWER_EMAIL and set a password.
  2. Log in as $REVIEWER_USERNAME, open Audit Trail Explorer, and run a search.
     It must return rows. This is the check no query can make for you.
  3. Record the org id and evidence above in docs/LIVE-ORG-VALIDATION.md.
     Never commit the password; it goes only into the submission wizard.
NEXT
