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
        return timeQuery(query, execution, 5);
    }
    double timeQuery(Query query, Execution execution, int count) {
        List<Long> timings = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            long before = System.nanoTime();
            Result result = execution.search(query);
            long after = System.nanoTime();
            timings.add(after - before);
        }
        Collections.sort(timings);
        int idx = 20 * count / 100;
        return timings.get(idx) * 1.0e-6;
    }

    @Override
    public Result search(Query weakAndQuery, Execution execution) {
        Result weakAndResult = execution.search(weakAndQuery);
        execution.fill(weakAndResult);
        var weakAndSet = getHitIds(weakAndResult);

        Query orQuery = changeRoot(weakAndQuery, new OrItem());
        long before = System.nanoTime();
        Result orResult = execution.search(orQuery);
        long after = System.nanoTime();
        double orTime = (after - before) * 1.0e-6;
        execution.fill(orResult);
        var orSet = getHitIds(orResult);

        Query andQuery = changeRoot(weakAndQuery, new AndItem());
        Result andResult = execution.search(andQuery);
        execution.fill(andResult);
        var andSet = getHitIds(andResult);

        Query weakAndQuery20 = changeRoot(weakAndQuery, new WeakAndItem());
        weakAndQuery20.properties().set("rankproperty.vespa.matching.weakand.stop_word_limit", "0.20");
        Result weakAndResult20 = execution.search(weakAndQuery20);
        execution.fill(weakAndResult20);
        var weakAndSet20 = getHitIds(weakAndResult20);

        Query weakAndQuery05 = changeRoot(weakAndQuery, new WeakAndItem());
        weakAndQuery05.properties().set("rankproperty.vespa.matching.weakand.stop_word_limit", "0.05");
        Result weakAndResult05 = execution.search(weakAndQuery05);
        execution.fill(weakAndResult05);
        var weakAndSet05 = getHitIds(weakAndResult05);

        // double orTime = timeQuery(orQuery, execution, 1);
        double weakAndTime = timeQuery(weakAndQuery, execution);
        double weakAndTime20 = timeQuery(weakAndQuery20, execution);
        double weakAndTime05 = timeQuery(weakAndQuery05, execution);
        double andTime = timeQuery(andQuery, execution);

        Hit meta = new Hit("meta");
        meta.setMeta(true);
        meta.setField("andQuality", quality(orSet, andSet));
        meta.setField("weakAndQuality", quality(orSet, weakAndSet));
        meta.setField("weakAndQuality20", quality(orSet, weakAndSet20));
        meta.setField("weakAndQuality05", quality(orSet, weakAndSet05));
        meta.setField("orHits", orResult.getTotalHitCount());
        meta.setField("andHits", andResult.getTotalHitCount());
        meta.setField("weakAndHits", weakAndResult.getTotalHitCount());
        meta.setField("weakAndHits20", weakAndResult20.getTotalHitCount());
        meta.setField("weakAndHits05", weakAndResult05.getTotalHitCount());
        meta.setField("orTime", orTime);
        meta.setField("andTime", andTime);
        meta.setField("weakAndTime", weakAndTime);
        meta.setField("weakAndTime20", weakAndTime20);
        meta.setField("weakAndTime05", weakAndTime05);
        Result result = new Result(weakAndQuery);
        result.setTotalHitCount(weakAndResult.getTotalHitCount());
        result.hits().add(meta);
        return result;
    }

}
