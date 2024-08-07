// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.StructuredData;

import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.After;

import com.yahoo.search.query.QueryTree;

import com.yahoo.data.access.*;

// various Item classes:
import com.yahoo.prelude.query.*;
import com.yahoo.prelude.hitfield.JSONString;

@Before("blendedResult")
@After("transformedQuery")
public class FriendFilterSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        String user = query.properties().getString("username");
        if (user == null) {
            query.trace("FriendFilterSearcher", true, 2);
            return execution.search(query);
        } else if (user.equals("default")) {
            query.getModel().setRestrict("blogpost");
            return hardCoded(query, execution);
        } else {
            return doLookup(query, execution, user);
        }
    }

    private Result hardCoded(Query query, Execution execution) {
        WeightedSetItem filter = new WeightedSetItem("author");
        filter.addToken("magazines", 2);
        filter.addToken("magazine2", 2);
        filter.addToken("magazine3", 2);
        filter.addToken("magazine4", 2);
        filter.addToken("tv", 3);
        filter.addToken("tabloids", 1);
        filter.addToken("tabloid2", 1);
        filter.addToken("tabloid3", 1);
        filter.addToken("tabloid4", 1);
        filter.addToken("tabloid5", 1);
        filter.addToken("tabloid6", 1);
        QueryTree tree = query.getModel().getQueryTree();
        Item oldroot = tree.getRoot();
        AndItem newtop = new AndItem();
        newtop.addItem(oldroot);
        newtop.addItem(filter);
        tree.setRoot(newtop);
        query.trace("FriendFilterSearcher :: ", true, 2);
        return execution.search(query);
    }

    private Item defaultFilter() {
        WeightedSetItem filter = new WeightedSetItem("author");
        filter.addToken("magazines", 2);
        filter.addToken("tv", 3);
        filter.addToken("tabloids", 1);
        return filter;
    }

    private Result doLookup(Query query, Execution execution, String user) {
        Item filter = lookupFriends(query, execution, user);
        QueryTree tree = query.getModel().getQueryTree();
        AndItem newtop = new AndItem();
        newtop.addItem(tree.getRoot());
        newtop.addItem(filter);
        tree.setRoot(newtop);
        query.getModel().setRestrict("blogpost");
        query.trace("FriendFilterSearcher :: ", true, 2);
        return execution.search(query);
    }

    private Item lookupFriends(Query query, Execution execution, String user) {
        Query listfriends = (Query)query.clone();
        WeightedSetItem filter = new WeightedSetItem("author");
        WordItem root = new WordItem(user);
        root.setIndexName("me");
        listfriends.getModel().getQueryTree().setRoot(root);
        listfriends.getModel().setRestrict("friendslist");
        query.trace("FriendFilterSearcher :: ", true, 2);
        Result friends = execution.search(listfriends);
        fill(friends, null, execution);
        for (Hit hit : friends.hits().asList()) {
            if (hit.isMeta()) continue;
            Object o = hit.getField("friends");
            if (o instanceof JSONString) {
                JSONString friendsfield = (JSONString)o;
                friendsfield.fillWeightedSetItem(filter);
            }
            if (o instanceof StructuredData) {
                StructuredData friendsfield = (StructuredData)o;
                Inspector arr = friendsfield.inspect();
                for (int i = 0; i < arr.entryCount(); i++) {
                    Inspector item = arr.entry(i);
                    String name = item.field("item").asString();
                    long weight = item.field("weight").asLong();
                    filter.addToken(name, (int)weight);
                }
            }
        }
        if (filter.getNumTokens() == 0) {
            query.trace("FriendFilterSearcher :: no friends, using default filter", false, 3);
            return defaultFilter();
        }
        return filter;
    }

}
