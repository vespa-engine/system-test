// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.search.*;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.prelude.query.*;
import com.yahoo.statistics.Value;
import com.yahoo.statistics.Limits;
import com.yahoo.statistics.Statistics;
import com.yahoo.statistics.HistogramType;
import java.util.Iterator;

public class QueryDepthSearcher extends Searcher {

    private Value queryDepth;

    public QueryDepthSearcher(Statistics manager) {
        queryDepth = new Value("query_depth", manager,
                new Value.Parameters()
                    .setLogHistogram(true)
                    .setHistogramId(HistogramType.REGULAR)
                    .setLimits(new Limits(new double[] { 0, 1, 2, 3 }))
                    .setLogMean(true)
                    .setNameExtension(false));
    }

    public Result search(Query query, Execution execution) {
        int depth = stackDepth(0, query.getModel().getQueryTree().getRoot());
        queryDepth.put(depth);

        return execution.search(query);
    }

    private int stackDepth(int i, Item root) {
        if (root == null) {
            return i;
        }
        if (root instanceof CompositeItem) {
            int maxDepth = i;
            for (Iterator j=((CompositeItem) root).getItemIterator(); j.hasNext();) {
                int newDepth = stackDepth(i+1, (Item)j.next());
                maxDepth = Math.max(maxDepth, newDepth);
            }
            return maxDepth;
        }
        else {
            return i;
        }
    }
}
