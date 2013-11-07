#!/bin/bash
################################################################################
# 
# Test script that access some web pages (should be run on a redirected device)
# 
################################################################################

WWWs=('http://seznam.cz' 'http://google.com')

while true
do
	for url in "${WWWs[@]}"
	do
		echo `date +"%Y-%m-%d %H:%M:%S"`"  Connecting to: $url" 1>&2
		out=`wget -q -O - "$url"`
		echo `date +"%Y-%m-%d %H:%M:%S"`"  Downloaded (\$? = $?)"
		echo ""
	done
done
