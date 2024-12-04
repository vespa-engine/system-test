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

        Query weakAndQueryA10 = changeRoot(weakAndQuery, new WeakAndItem());
        weakAndQueryA10.properties().set("rankproperty.vespa.matching.weakand.stop_word_adjust_limit", "0.10");
        Result weakAndResultA10 = execution.search(weakAndQueryA10);
        execution.fill(weakAndResultA10);
        var weakAndSetA10 = getHitIds(weakAndResultA10);

        Query weakAndQueryA02 = changeRoot(weakAndQuery, new WeakAndItem());
        weakAndQueryA02.properties().set("rankproperty.vespa.matching.weakand.stop_word_adjust_limit", "0.02");
        Result weakAndResultA02 = execution.search(weakAndQueryA02);
        execution.fill(weakAndResultA02);
        var weakAndSetA02 = getHitIds(weakAndResultA02);

        Query weakAndQueryD20 = changeRoot(weakAndQuery, new WeakAndItem());
        weakAndQueryD20.properties().set("rankproperty.vespa.matching.weakand.stop_word_drop_limit", "0.20");
        Result weakAndResultD20 = execution.search(weakAndQueryD20);
        execution.fill(weakAndResultD20);
        var weakAndSetD20 = getHitIds(weakAndResultD20);

        Query weakAndQueryD05 = changeRoot(weakAndQuery, new WeakAndItem());
        weakAndQueryD05.properties().set("rankproperty.vespa.matching.weakand.stop_word_drop_limit", "0.05");
        Result weakAndResultD05 = execution.search(weakAndQueryD05);
        execution.fill(weakAndResultD05);
        var weakAndSetD05 = getHitIds(weakAndResultD05);

        Query weakAndQueryX = changeRoot(weakAndQuery, new WeakAndItem());
        weakAndQueryX.properties().set("rankproperty.vespa.matching.weakand.stop_word_adjust_limit", "0.01");
        weakAndQueryX.properties().set("rankproperty.vespa.matching.diskindex.bitvector_limit", "0.05");
        weakAndQueryX.properties().set("rankproperty.vespa.matching.weakand.stop_word_drop_limit", "0.60");
        Result weakAndResultX = execution.search(weakAndQueryX);
        execution.fill(weakAndResultX);
        var weakAndSetX = getHitIds(weakAndResultX);

        Query weakAndQueryY = changeRoot(weakAndQuery, new WeakAndItem());
        weakAndQueryY.properties().set("rankproperty.vespa.matching.weakand.stop_word_adjust_limit", "0.01");
        weakAndQueryY.properties().set("rankproperty.vespa.matching.weakand.stop_word_drop_limit", "0.60");
        Result weakAndResultY = execution.search(weakAndQueryY);
        execution.fill(weakAndResultY);
        var weakAndSetY = getHitIds(weakAndResultY);

        // double orTime = timeQuery(orQuery, execution, 1);
        double weakAndTime = timeQuery(weakAndQuery, execution);
        double weakAndTimeA10 = timeQuery(weakAndQueryA10, execution);
        double weakAndTimeA02 = timeQuery(weakAndQueryA02, execution);
        double weakAndTimeD20 = timeQuery(weakAndQueryD20, execution);
        double weakAndTimeD05 = timeQuery(weakAndQueryD05, execution);
        double weakAndTimeX = timeQuery(weakAndQueryX, execution);
        double weakAndTimeY = timeQuery(weakAndQueryY, execution);
        double andTime = timeQuery(andQuery, execution);

        Hit meta = new Hit("meta");
        meta.setMeta(true);
        meta.setField("andQuality", quality(orSet, andSet));
        meta.setField("weakAndQuality", quality(orSet, weakAndSet));
        meta.setField("weakAndQualityA10", quality(orSet, weakAndSetA10));
        meta.setField("weakAndQualityA02", quality(orSet, weakAndSetA02));
        meta.setField("weakAndQualityD20", quality(orSet, weakAndSetD20));
        meta.setField("weakAndQualityD05", quality(orSet, weakAndSetD05));
        meta.setField("weakAndQualityX", quality(orSet, weakAndSetX));
        meta.setField("weakAndQualityY", quality(orSet, weakAndSetY));
        meta.setField("orHits", orResult.getTotalHitCount());
        meta.setField("andHits", andResult.getTotalHitCount());
        meta.setField("weakAndHits", weakAndResult.getTotalHitCount());
        meta.setField("weakAndHitsA10", weakAndResultA10.getTotalHitCount());
        meta.setField("weakAndHitsA02", weakAndResultA02.getTotalHitCount());
        meta.setField("weakAndHitsD20", weakAndResultD20.getTotalHitCount());
        meta.setField("weakAndHitsD05", weakAndResultD05.getTotalHitCount());
        meta.setField("weakAndHitsX", weakAndResultX.getTotalHitCount());
        meta.setField("weakAndHitsY", weakAndResultY.getTotalHitCount());
        meta.setField("orTime", orTime);
        meta.setField("andTime", andTime);
        meta.setField("weakAndTime", weakAndTime);
        meta.setField("weakAndTimeA10", weakAndTimeA10);
        meta.setField("weakAndTimeA02", weakAndTimeA02);
        meta.setField("weakAndTimeD20", weakAndTimeD20);
        meta.setField("weakAndTimeD05", weakAndTimeD05);
        meta.setField("weakAndTimeX", weakAndTimeX);
        meta.setField("weakAndTimeY", weakAndTimeY);
        Result result = new Result(weakAndQuery);
        result.setTotalHitCount(weakAndResult.getTotalHitCount());
        result.hits().add(meta);
        return result;
    }

}
