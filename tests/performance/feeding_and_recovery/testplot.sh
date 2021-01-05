#!/bin/sh
lastdir=$(ls /home/y/logs/systemtests/command-line/ | sort | tail -1)
echo /home/y/logs/systemtests/command-line/$lastdir/*/*/results/performance
./myplot.rb /home/y/logs/systemtests/command-line/$lastdir/*/*/results/performance
