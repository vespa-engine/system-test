// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.component.chain.dependencies.After;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.NullItem;
import com.yahoo.prelude.query.AndItem;
import com.yahoo.prelude.query.OrItem;
import com.yahoo.prelude.query.RankItem;
import com.yahoo.prelude.query.CompositeItem;
import com.yahoo.prelude.query.DotProductItem;
import com.yahoo.yolean.Exceptions;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.ErrorMessage;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.text.MapParser;

import java.util.logging.Level;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Map.Entry;

import static com.yahoo.container.protect.Error.UNSPECIFIED;
import static com.yahoo.prelude.querytransform.NormalizingSearcher.ACCENT_REMOVAL;
import static com.yahoo.prelude.querytransform.StemmingSearcher.STEMMING;

@After({ STEMMING, ACCENT_REMOVAL })
public class ItemRawScoreTestSearcher extends Searcher {

    private static class IntegerMapParser extends MapParser<Integer> {
        @Override
        protected Integer parseValue(String s) {
            return Integer.parseInt(s);
        }
    }

    @Override
    public Result search(Query query, Execution execution) {
        try {
            OrItem or_normal_item = new OrItem();
            or_normal_item.addItem(buildNormalQueryItem("normal_features","normal_foo", new IntegerMapParser().parse("{foo:1}", new LinkedHashMap<String,Integer>())));
            or_normal_item.addItem(buildNormalQueryItem("normal_features","normal_bar", new IntegerMapParser().parse("{bar:1}", new LinkedHashMap<String,Integer>())));
            or_normal_item.addItem(buildNormalQueryItem("normal_features","normal_baz", new IntegerMapParser().parse("{baz:1}", new LinkedHashMap<String, Integer>())));

            OrItem or_normal_fastsearch_item = new OrItem();
            or_normal_item.addItem(buildNormalQueryItem("normal_features_fastsearch","normal_fastsearch_foo", new IntegerMapParser().parse("{foo:1}", new LinkedHashMap<String,Integer>())));
            or_normal_item.addItem(buildNormalQueryItem("normal_features_fastsearch","normal_fastsearch_bar", new IntegerMapParser().parse("{bar:1}", new LinkedHashMap<String,Integer>())));
            or_normal_item.addItem(buildNormalQueryItem("normal_features_fastsearch","normal_fastsearch_baz", new IntegerMapParser().parse("{baz:1}", new LinkedHashMap<String, Integer>())));

            OrItem root = new OrItem();
            root.addItem(or_normal_item);
            root.addItem(or_normal_fastsearch_item);

            Item oldRoot = query.getModel().getQueryTree().getRoot();
            if (oldRoot != null && !(oldRoot instanceof NullItem)) {
                CompositeItem combined;
                if(query.properties().getBoolean("useRank",false)) {
                    combined = new RankItem();
                } else {
                    combined = new OrItem();
                }
                combined.addItem(oldRoot);
                combined.addItem(root);
                query.getModel().getQueryTree().setRoot(combined);
            } else {
                query.getModel().getQueryTree().setRoot(root);
            }
            getLogger().log(Level.INFO, "Query plan " + query);
            return execution.search(query);
        } catch (Exception e) {
            return new Result(query, new ErrorMessage(UNSPECIFIED.code, "Shit happened", Exceptions.toMessageString(e)));
        }
    }

    private Item buildNormalQueryItem(String field,String label,Map<String,Integer> vector) throws Exception {
        DotProductItem dotProduct = new DotProductItem(field);
        dotProduct.setLabel(label);
        for(Map.Entry<String,Integer> e : vector.entrySet()) {
            dotProduct.addToken(e.getKey(),e.getValue());
        }
        return dotProduct;

    }

}
