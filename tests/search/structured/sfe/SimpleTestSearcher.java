// Copyright Vespa.ai. All rights reserved.
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
            if (hit.isMeta()) continue;
            Object o = hit.getField("summaryfeatures");
            if (o instanceof Inspectable) {
                Inspectable summaryfeatures = (Inspectable) o;
                Inspector obj = summaryfeatures.inspect();
                if (obj.field("fieldMatch(title)").asDouble(0.0) > 0.85) {
                        hit.setField("goodmatch", "good title");
                }
                if (obj.field("fieldMatch(title)").asDouble(0.0) > 0.95) {
                        hit.setField("goodmatch", "super good title");
                }
                if (obj.field("attribute(quality)").asDouble(0.0) > 0.4) {
                        hit.setField("qualitysource", "good quality");
                }
                if (obj.field("attribute(quality)").asDouble(0.0) > 0.9) {
                        hit.setField("qualitysource", "super good quality");
                }
                hit.removeField("summaryfeatures");
            }
        }
        return r;
    }

}
