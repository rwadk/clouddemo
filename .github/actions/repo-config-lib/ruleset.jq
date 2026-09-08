# Strip everything the server invented, then impose a canonical order.
#
# A ruleset GET returns eight fields nobody wrote — id, node_id, timestamps,
# _links, source, source_type, current_user_can_bypass — and returns rules and
# bypass actors in whatever order it likes. Both have to go before a diff means
# anything. Sorting is also what makes element-wise projection valid, since
# that aligns the two arrays by index.

# Underscore-prefixed keys are config-file commentary. They are stripped here
# so they never reach a diff, and stripped again before any POST/PUT so the
# API never sees a field it does not know.
with_entries(select(.key | startswith("_") | not))
| del(.id, .node_id, .created_at, .updated_at, ._links,
    .source, .source_type, .current_user_can_bypass)
| .rules         = ((.rules // []) | sort_by(.type))
| .bypass_actors = ((.bypass_actors // []) | sort_by([(.actor_type // ""), (.actor_id // 0)]))
| .rules = (.rules | map(
    if .type == "required_status_checks" then
      .parameters.required_status_checks = ((.parameters.required_status_checks // []) | sort_by(.context))
    else . end))
