// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;

import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.After;

import com.yahoo.search.query.QueryTree;

// various Item classes:
import com.yahoo.prelude.query.*;

import java.util.List;
import java.util.ArrayList;

@Before("blendedResult")
@After("transformedQuery")
public class EquivTestSearcher extends Searcher {

    private java.util.Map<String, DictEntry> dict;

    public EquivTestSearcher() {
        initDict();
    }

    private class DictEntry {
        DictEntry(String k) {
            this.keyword = k;
        }
        public String keyword;
        public List<String> synonyms = new ArrayList<String>();
    }

    private void initDict() {
        dict = new java.util.HashMap<String, DictEntry>();

        // pretend we have a dictionary entry:
        DictEntry e = new DictEntry("a");
        e.synonyms.add("5");
        e.synonyms.add("x");

        // and put it in the dictionary:
        dict.put(e.keyword, e);
    }


    private Item equivize(Item item) {
        if (item instanceof TermItem) {
            String word = ((TermItem)item).stringValue();

            // lookup word in dictionary:
            DictEntry entry = dict.get(word);

            // if synonyms found, make equiv and replace this word:
            if (entry != null) {
                EquivItem eq = new EquivItem(item, entry.synonyms);
                return eq;
            }
        } else if (item instanceof PhraseItem ||
                   item instanceof PhraseSegmentItem) {
            // cannot put EQUIV inside PHRASE
            return item;
        } else if (item instanceof CompositeItem) {
            CompositeItem cmp = (CompositeItem)item;
            for (int i = 0; i < cmp.getItemCount(); ++i) {
                cmp.setItem(i, equivize(cmp.getItem(i)));
            }
            return cmp;
        }
        return item;
    }

    public Result search(Query query, Execution execution) {
        QueryTree tree = query.getModel().getQueryTree();
        tree.setRoot(equivize(tree.getRoot()));
        return execution.search(query);
    }
}
