// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.search.*;
import com.yahoo.search.result.*;
import com.yahoo.search.searchchain.*;
import com.yahoo.yolean.chain.After;
import com.yahoo.yolean.chain.Before;
import com.yahoo.data.access.*;

@After(PhaseNames.TRANSFORMED_QUERY)
@Before(PhaseNames.BLENDED_RESULT)
public class SimpleTestSearcher extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        Result r = execution.search(query);
        execution.fill(r);
        for (Hit hit : r.hits().asList()) {
            processHit(hit);
        }
        return r;
    }

    void processHit(Hit hit) {
        if (hit.isMeta()) return;
        Object o = hit.getField("titles");
        if (o instanceof Inspectable) {
            StringBuilder pasteBuf = new StringBuilder();
            Inspectable field = (Inspectable) o;
            Inspector arr = field.inspect();
            for (int i = 0; i < arr.entryCount(); i++) {
                String sval = arr.entry(i).field("item").asString("");
                long weight = arr.entry(i).field("weight").asLong(0);
                pasteBuf.append("title: ");
                pasteBuf.append(sval);
                pasteBuf.append("[");
                pasteBuf.append(weight);
                pasteBuf.append("]");
                if (i+1 < arr.entryCount()) {
                    pasteBuf.append(", ");
                }
            }
            hit.setField("alternates", pasteBuf.toString());
        }
    }

}
