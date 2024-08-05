// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.search.result.Hit;
import com.yahoo.prelude.query.DotProductItem;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.OrItem;
import com.yahoo.yolean.Exceptions;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.query.QueryTree;
import com.yahoo.search.result.ErrorMessage;
import com.yahoo.yolean.chain.After;
import com.yahoo.yolean.chain.Before;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.text.MapParser;
import java.util.LinkedHashMap;
import java.util.Map;
import com.yahoo.data.access.Inspectable;
import com.yahoo.data.access.Inspector;
import java.util.Iterator;

import static com.yahoo.container.protect.Error.UNSPECIFIED;
import static com.yahoo.prelude.querytransform.NormalizingSearcher.ACCENT_REMOVAL;
import static com.yahoo.prelude.querytransform.StemmingSearcher.STEMMING;

@After({ STEMMING, ACCENT_REMOVAL })
public class SummaryInspector extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        execution.fill(result);
        for (Iterator<Hit> i = result.hits().deepIterator(); i.hasNext(); ) {
            Hit hit = i.next();
	    if (!hit.isMeta()) {
                Object sf = hit.getField("attr");
                if (sf != null) {
                    if (sf instanceof Inspectable) {
                        Inspector value = ((Inspectable)sf).inspect();
                        if ((value.entry(0).asLong(0) == 42L) &&
                            (value.entry(1).asLong(0) == 1337L) &&
                            (value.entry(2).asLong(1234) == 1234L))
                        {
                            hit.setField("check", "ok");
                        }
                    }
                }
            }
        }
        return result;
    }
}
