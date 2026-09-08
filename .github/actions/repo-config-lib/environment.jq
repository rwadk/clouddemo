# Live environments do not come back in the shape you write them.
#
# A GET returns protection_rules as a heterogeneous array — one object per
# rule type, each with its own server-assigned id — plus reviewers nested
# under .reviewer with the full user object. A PUT expects flat fields and
# reviewers by numeric id. Diffing the raw GET against config would report
# drift on every field, every run.
#
# This flattens live state into exactly the shape environments.json declares.
# Reviewers are reduced to login: ids are unreadable in a config file and
# unstable to review in a diff, so config carries logins and apply resolves
# them back to ids.

def rule($t): (.protection_rules // []) | map(select(.type == $t)) | first;

{
  name:                     .name,
  wait_timer:               ((rule("wait_timer") | .wait_timer) // 0),
  prevent_self_review:      ((rule("required_reviewers") | .prevent_self_review) // false),
  reviewers:                ((rule("required_reviewers") | .reviewers // [])
                             | map({ type: .type, login: .reviewer.login })
                             | sort_by(.login)),
  deployment_branch_policy: (.deployment_branch_policy // null)
}
