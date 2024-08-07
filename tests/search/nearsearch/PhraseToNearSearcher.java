// Copyright Vespa.ai. All rights reserved.
package com.yahoo.nearsearch;

import java.util.logging.Level;
import java.util.logging.Logger;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;

import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.After;

import com.yahoo.search.query.QueryTree;

// various Item classes:
import com.yahoo.prelude.query.*;


@Before("blendedResult")
@After("transformedQuery")
public class PhraseToNearSearcher extends Searcher {

    private final Logger log = Logger.getLogger(PhraseToNearSearcher.class.getName());

    @Override
    public Result search(Query query, Execution execution) {
        query.trace("PhraseToNearSearcher", true, 1);
        QueryTree tree = query.getModel().getQueryTree();
        log.log(Level.INFO, "Before: " + tree.getRoot());
        tree.setRoot(replacePhrase(tree.getRoot()));
        log.log(Level.INFO, "After: " + tree.getRoot());
        query.trace("PhraseToNearSearcher", true, 1);
        return execution.search(query);
    }

    private Item replacePhrase(Item item) {
        if (item instanceof CompositeItem) {
            if (item instanceof PhraseItem) {
                PhraseItem phrase = (PhraseItem)item;
                int len = phrase.getItemCount();
                NearItem near = new NearItem(len);
                for (int i = 0; i < len; ++i) {
                    near.addItem(phrase.removeItem(0));
                }
                item = near;
            }
            CompositeItem cmp = (CompositeItem)item;
            for (int i = 0; i < cmp.getItemCount(); ++i) {
                cmp.setItem(i, replacePhrase(cmp.getItem(i)));
            }
        }
        return item;
    }
}
