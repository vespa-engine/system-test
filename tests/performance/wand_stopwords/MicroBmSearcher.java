// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.prelude.query.AndItem;
import com.yahoo.prelude.query.CompositeItem;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.OrItem;
import com.yahoo.prelude.query.WeakAndItem;
import com.yahoo.search.*;
import com.yahoo.search.result.*;
import com.yahoo.search.searchchain.*;
import com.yahoo.yolean.chain.After;
import com.yahoo.yolean.chain.Before;
import com.yahoo.data.access.*;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@After(PhaseNames.TRANSFORMED_QUERY)
@Before(PhaseNames.BLENDED_RESULT)
public class MicroBmSearcher extends Searcher {

    Query changeRoot(Query query, CompositeItem newRoot) {
        Query newQuery = query.clone();
        Item oldRoot = newQuery.getModel().getQueryTree().getRoot();
        if (oldRoot instanceof CompositeItem old) {
            for (Item child : old.items()) {
                newRoot.addItem(child);
            }
        }
        newQuery.getModel().getQueryTree().setRoot(newRoot);
        return newQuery;
    }

    Set<String> getHitIds(Result result) {
        Set<String> set = new HashSet<>();
        for (Hit hit : result.hits().asList()) {
            if (hit.isMeta()) continue;
            String id = hit.getDisplayId();
            set.add(id);
        }
        return set;
    }

    double quality(Set<String> expected, Set<String> actual) {
        int count = 0;
        for (String id : expected) {
            if (actual.contains(id)) {
                ++count;
            }
        }
        return (double)count / (double)expected.size();
    }

    double timeQuery(Query query, Execution execution) {
        List<Long> timings = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            long before = System.nanoTime();
            Result result = execution.search(query);
            long after = System.nanoTime();
            timings.add(after - before);
        }
        Collections.sort(timings);
        return timings.get(2) * 1.0e-6;
    }

    @Override
    public Result search(Query weakAndQuery, Execution execution) {
        Result weakAndResult = execution.search(weakAndQuery);
        execution.fill(weakAndResult);
        var weakAndSet = getHitIds(weakAndResult);

        Query orQuery = changeRoot(weakAndQuery, new OrItem());
        Result orResult = execution.search(orQuery);
        execution.fill(orResult);
        var orSet = getHitIds(orResult);

        Query andQuery = changeRoot(weakAndQuery, new AndItem());
        Result andResult = execution.search(andQuery);
        execution.fill(andResult);
        var andSet = getHitIds(andResult);

        double weakAndTime = timeQuery(weakAndQuery, execution);
        double andTime = timeQuery(andQuery, execution);
        double orTime = timeQuery(orQuery, execution);

        Hit meta = new Hit("meta");
        meta.setMeta(true);
        meta.setField("andQuality", quality(orSet, andSet));
        meta.setField("weakAndQuality", quality(orSet, weakAndSet));
        meta.setField("orHits", orResult.getTotalHitCount());
        meta.setField("andHits", andResult.getTotalHitCount());
        meta.setField("weakAndHits", weakAndResult.getTotalHitCount());
        meta.setField("orTime", orTime);
        meta.setField("andTime", andTime);
        meta.setField("weakAndTime", weakAndTime);
        Result result = new Result(weakAndQuery);
        result.setTotalHitCount(weakAndResult.getTotalHitCount());
        result.hits().add(meta);
        return result;
    }

}
