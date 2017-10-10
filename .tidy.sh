#!/bin/bash -e
PT=perltidy
[ `type -t $PT` ] || type $PT
$PT -b *.t tx/*.t bin/*.pl
grep . *.t.ERR tx/*.t.ERR bin/*.pl.ERR || true
rm *.t.bak tx/*.t.bak bin/*.pl.bak *.t.ERR tx/*.t.ERR bin/*.pl.ERR
