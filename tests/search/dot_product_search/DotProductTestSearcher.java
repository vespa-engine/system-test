// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

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
import static com.yahoo.container.protect.Error.UNSPECIFIED;
import static com.yahoo.prelude.querytransform.NormalizingSearcher.ACCENT_REMOVAL;
import static com.yahoo.prelude.querytransform.StemmingSearcher.STEMMING;

@After({ STEMMING, ACCENT_REMOVAL })
public class DotProductTestSearcher extends Searcher {

    private static class IntegerMapParser extends MapParser<Integer> {
        @Override protected Integer parseValue(String s) { return Integer.parseInt(s); }
    }

    private static Item makeDotProduct(String label, String field, Map<String,Integer> token_map) {
        DotProductItem item = new DotProductItem(field);
        item.setLabel(label);
        for (Map.Entry<String,Integer> entry : token_map.entrySet()) {
            item.addToken(entry.getKey(), entry.getValue());
        }
        return item;
    }

    @Override
    public Result search(Query query, Execution execution) {
        IntegerMapParser parser = new IntegerMapParser();
        for (int i = 1; i <= 9; i++) {
            String field = query.properties().getString(String.format("dp%d.field", i));
            String tokens = query.properties().getString(String.format("dp%d.tokens", i));
            if (field != null && tokens != null) {
                String label = String.format("dp%d", i);
                Map<String,Integer> token_map = parser.parse(tokens, new LinkedHashMap<String,Integer>());
                query.getModel().getQueryTree().and(makeDotProduct(label, field, token_map));
            }
        }
        return execution.search(query);
    }
}
