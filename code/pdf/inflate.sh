#!/bin/sh

( /bin/echo -ne '\037\0213\010\0\0\0\0\0' ; cat "$@" ) | gzip -dc 2>/dev/null
