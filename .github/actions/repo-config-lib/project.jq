# Project live API state onto the shape of the declared config.
#
# The repo object alone returns 97 fields; a ruleset GET adds id, node_id,
# timestamps and _links that nobody wrote. Comparing whole objects means
# permanent false drift, so config is treated as a statement about the keys
# it mentions and silent about everything else.
#
# Recurses through objects only. Arrays are compared wholesale, so any
# resource with order-unstable arrays must canonicalise them in its own
# normalise filter before calling this.

def project($d):
  . as $a
  | if ($d | type) == "object" and ($a | type) == "object" then
      reduce ($d | keys_unsorted[]) as $k ({};
        .[$k] = ($a[$k] | project($d[$k])))
    else
      $a
    end;

project($desired[0])
