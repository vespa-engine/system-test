// Copyright Vespa.ai. All rights reserved.
package com.yahoo.nearsearch;

import com.yahoo.prelude.query.*;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.Iterator;
import java.util.Stack;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;

public class PhraseToONearSearcher extends Searcher {

    private final Logger log = Logger.getLogger(PhraseToONearSearcher.class.getName());

    @Override
    public Result search(Query query, Execution execution) {
        log.log(Level.INFO, "Before: " + query.getModel().getQueryTree().getRoot());
        query.getModel().getQueryTree().setRoot(replacePhrase(query.getModel().getQueryTree().getRoot()));
        log.log(Level.INFO, "After: " + query.getModel().getQueryTree().getRoot());

        Result ret = execution.search(query);
        ret.trace("there is no spoon");
        return ret;
    }

    private Item replacePhrase(Item item) {
        if (item instanceof CompositeItem) {
            if (item instanceof PhraseItem) {
                PhraseItem phrase = (PhraseItem)item;
                int len = phrase.getItemCount();
                ONearItem near = new ONearItem(len - 1);
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
