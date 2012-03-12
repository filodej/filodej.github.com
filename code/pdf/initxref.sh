#!/bin/bash

PDF=$1
XREF=$PDF.xref

if [ $PDF ]; then
  OFFSET=`tail -n2 $PDF | head -n1`
  dd if=$PDF bs=1 skip=$OFFSET 2>/dev/null | sed 1,3d | awk '{print NR,$0}' > $XREF
else
  echo "Usage: $0 <pdf-file>"
  exit 1
fi
