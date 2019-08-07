#!/bin/bash

python scrape.py https://archive.org/download/stackexchange/ 7z
rm *.meta.*
./runme.sh 
