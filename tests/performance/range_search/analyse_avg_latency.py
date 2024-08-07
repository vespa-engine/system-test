# Copyright Vespa.ai. All rights reserved.

import sys
import xml.etree.ElementTree as ET
 
def get_avg_latency(file_name):
    tree = ET.parse(file_name)
    root = tree.getroot()
    label = None
    range_ratio = 0
    values = 0
    filter_ratio = 0
    avg_latency = 0
    for child in root:
        if child.tag == 'metrics':
            for metric in child:
                if metric.attrib['name'] == 'avgresponsetime':
                    avg_latency = float(metric.text)
        elif child.tag == 'parameters':
            for param in child:
                attr = param.attrib['name']
                if attr == 'label':
                    label = param.text
                elif attr == 'range_hits_ratio':
                    range_ratio = int(param.text)
                elif attr == 'values_in_range':
                    values = int(param.text)
                elif attr == 'filter_hits_ratio':
                    filter_ratio = int(param.text)
    return [label, range_ratio, values, filter_ratio, avg_latency]


# Script used to analyze the results of running the performance test manually.
#
# Example usage:
# ls $VESPA_HOME/logs/systemtests/RangeSearchPerfTest/range_search/results/performance/*.xml | python3 analyse_avg_latency.py

for file_name in sys.stdin:
    val = get_avg_latency(file_name.strip())
    if val[0]:
        print(*val, sep=";")

