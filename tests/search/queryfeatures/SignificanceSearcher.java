// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.queryfeatures;

import com.yahoo.search.Searcher;
import com.yahoo.search.Result;
import com.yahoo.search.Query;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.prelude.query.*;

public class SignificanceSearcher extends Searcher {

    private WordItem findWordItem(String term, Query query) {
        if (query.getModel().getQueryTree().getRoot() instanceof CompositeItem) {
            CompositeItem root = (CompositeItem) query.getModel().getQueryTree().getRoot();
            query.trace("try to find: '" + term + "'", true, 9);
            for (int i = 0; i < root.getItemCount(); ++i) {
                WordItem item = (WordItem) root.getItem(i);
                if (term.equals(item.getWord())) {
                    query.trace("term '" + term + "' found", true, 9);
                    return item;
                }
            }
        }
        return null;
    }

    private void setSignificance(String significance, Query query) {
        String [] s = significance.split(":");
        String term = s[0];
        float value = Float.parseFloat(s[1]);

        WordItem item = findWordItem(term, query);

        if (item != null) {
            query.trace("setSignificance: '" + item.getWord() + "':'" + value, true, 9);
            item.setSignificance(value);
        }
    }

    @Override
    public Result search(Query query, Execution execution) {
        String significance = query.properties().getString("significance");
        if (significance == null) {
            return execution.search(query);
        }

        query.trace("significance='" + significance + "'", true, 9);

        String [] s = significance.split(",");
        for (int i = 0; i < s.length; ++i) {
            setSignificance(s[i], query);
        }

        return execution.search(query);
    }

}
