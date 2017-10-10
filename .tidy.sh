#!/bin/bash -e
PT=perltidy
[ `type -t $PT` ] || type $PT
$PT -b *.t tx/*.t
rm *.t.bak tx/*.t.bak
