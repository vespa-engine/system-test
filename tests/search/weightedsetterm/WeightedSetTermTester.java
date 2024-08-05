// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;

import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.After;

import com.yahoo.search.query.QueryTree;

// various Item classes:
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.AndItem;
import com.yahoo.prelude.query.WeightedSetItem;

import java.util.Map;
import java.util.HashMap;

@Before("blendedResult")
@After("transformedQuery")
public class WeightedSetTermTester extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        String tokenlist = query.properties().getString("ws.tokens");
        String fieldname = query.properties().getString("ws.field");

        if (tokenlist != null && fieldname != null && addWeightedSet(query, fieldname, tokenlist)) {
            query.trace("WeightedSetTermTester added weighted set", true, 2);
        } else {
            query.trace("WeightedSetTermTester is NOP", false, 2);
        }
        return execution.search(query);
    }

    private boolean addWeightedSet(Query query, String fieldname, String tokenlist) {
        Map<String, Integer> tokens = splitTokenlist(tokenlist);
        if (tokens.size() > 0) {
            WeightedSetItem filter = new WeightedSetItem(fieldname);
            for (Map.Entry<String, Integer> token : tokens.entrySet()) {
                filter.addToken(token.getKey(), token.getValue());
            }
            QueryTree tree = query.getModel().getQueryTree();
            if (tree.isEmpty()) {
                tree.setRoot(filter);
            } else {
                Item oldroot = tree.getRoot();
                if (oldroot.getClass() == AndItem.class) {
                    ((AndItem)oldroot).addItem(filter);
                } else {
                    AndItem newtop = new AndItem();
                    newtop.addItem(oldroot);
                    newtop.addItem(filter);
                    tree.setRoot(newtop);
                }
            }
            return true;
        }
        return false;
    }

    private Map<String, Integer> splitTokenlist(String tokenlist) {
        try {
            Map<String, Integer> map = new HashMap<String, Integer>();
            String[] wtlist = tokenlist.split(",");
            for (String wtoken : wtlist) {
                String[] pair = wtoken.split(":");
                if (pair.length != 2) {
                    throw new IllegalArgumentException("expected token:weight");
                }
                map.put(pair[0], new Integer(pair[1]));
            }
            return map;
        } catch (IllegalArgumentException e) {
            // also catches number format exception
            return new HashMap<String, Integer>();
        }
    }
}
