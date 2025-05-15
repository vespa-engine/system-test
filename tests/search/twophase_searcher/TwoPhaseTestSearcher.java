// Copyright Vespa.ai. All rights reserved.
package com.yahoo.example;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import java.util.Iterator;

public class TwoPhaseTestSearcher extends Searcher {

    private Hit mkHit(String text) {
        var hit = new Hit(text, 1000);
        hit.setField("marker", text);
        return hit;
    }

    @Override
    public Result search(Query query, Execution execution) {
        query.trace("running TwoPhaseTestSearcher", false, 1);

        Result result = execution.search(query);

        query.trace("before fill", false, 1);
        for (Iterator<Hit> i = result.hits().deepIterator(); i.hasNext(); ) {
            Hit hit = i.next();
            if (hit.getField("title") != null) {
                query.trace("got title before fill: "+hit.toString(), false, 1);
                result.hits().add(mkHit("bad"));
                return result;
            }

        }
        execution.fill(result);
        query.trace("after fill", false, 1);
        for (Iterator<Hit> i = result.hits().deepIterator(); i.hasNext(); ) {
            Hit hit = i.next();
            if (hit.isMeta()) continue;
            if (hit.getField("title") == null) {
                query.trace("no title after fill: "+hit.toString(), false, 1);
                result.hits().add(mkHit("bad"));
                return result;
            }

        }

        result.hits().add(mkHit("good"));

        return result;
    }
}
