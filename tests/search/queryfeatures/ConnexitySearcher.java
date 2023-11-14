// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.queryfeatures;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.prelude.query.*;

public class ConnexitySearcher extends Searcher {

    private WordItem findWordItem(String term, Query query) {
        if (query.getModel().getQueryTree().getRoot() instanceof CompositeItem) {
            CompositeItem root = (CompositeItem) query.getModel().getQueryTree().getRoot();
            query.trace("try to find: '" + term + "'", false, 9);
            for (int i = 0; i < root.getItemCount(); ++i) {
                WordItem item = (WordItem) root.getItem(i);
                if (term.equals(item.getWord())) {
                    query.trace("term '" + term + "' found", false, 9);
                    return item;
                }
            }
        }
        return null;
    }

    private void setConnexity(String connexity, Query query) {
        String [] c = connexity.split(":");
        String fromTerm = c[0];
        String toTerm = c[1];
        float value = Float.parseFloat(c[2]);

        WordItem fromItem = findWordItem(fromTerm, query);
        WordItem toItem = findWordItem(toTerm, query);

        if (fromItem != null && toItem != null) {
            query.trace("setConnectivity: '" + fromItem.getWord() + "':'" + toItem.getWord() + "':'" + value, false, 9);
            fromItem.setConnectivity(toItem, value);
        }
    }

    public Result search(Query query, Execution execution) {
        String connexity = query.properties().getString("connexity");
        if (connexity == null) {
            return execution.search(query);
        }

        query.trace("connexity='" + connexity + "'", false, 9);

        String [] c = connexity.split(",");
        for (int i = 0; i < c.length; ++i) {
            setConnexity(c[i], query);
        }

        return execution.search(query);
    }
}
