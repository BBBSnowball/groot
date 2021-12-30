#!/usr/bin/env bash
cd "$(dirname "$0")"/src
find -name .git -print | while read x ; do y="$(git -C "$(dirname "$x")" status --porcelain)"; if [ -n "$y" ] ; then echo ""; echo "== $x =="; echo "$y"; echo ""; else echo -n .; fi ; done
