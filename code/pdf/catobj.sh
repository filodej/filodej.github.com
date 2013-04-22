#!/bin/bash

PDF=$1
OBJ=$2
OUTSIZE=$3
RELOFFSET=$4
XREF=$PDF.xref

if [ $PDF ] && [ $OBJ ]; then
  STROFFSET=$(grep -e "^$OBJ " $XREF | cut -d" " -f2)
  OFFSET=$(echo "0$RELOFFSET + $STROFFSET" | bc)
  if [ $OUTSIZE ]; then
    dd if=$PDF bs=1 skip=$OFFSET count=$OUTSIZE 2>/dev/null
  else
    dd if=$PDF bs=1 skip=$OFFSET 2>/dev/null | sed -e '/endobj/,/%%EOF/ c endobj'
  fi
else
  echo "Usage: $0 <pdf-file> <object-nr> [output-size] [<rel-offset>]"
  exit 1
fi
