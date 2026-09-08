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
    elif ($d | type) == "array" and ($a | type) == "array"
         and (($d | length) == ($a | length)) then
      # Equal-length arrays are projected element-wise. A ruleset GET returns
      # every parameter of every rule whether or not it was declared, so
      # comparing rule objects whole would be permanent drift. Callers sort
      # arrays canonically first, which is what makes index alignment valid.
      # Mismatched lengths mean a rule was added or removed — real drift, so
      # the arrays are compared whole and the difference shows.
      [ range(0; $d | length) as $i | ($a[$i] | project($d[$i])) ]
    else
      $a
    end;

project($desired[0])
