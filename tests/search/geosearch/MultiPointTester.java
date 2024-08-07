// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;

import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.After;

import com.yahoo.search.query.QueryTree;

import com.yahoo.prelude.Location;

// various Item classes:
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.AndItem;
import com.yahoo.prelude.query.OrItem;
import com.yahoo.prelude.query.GeoLocationItem;

import java.util.Map;
import java.util.HashMap;

@Before("blendedResult")
@After("transformedQuery")
public class MultiPointTester extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        String active = query.properties().getString("multipointtester");
        if (active != null) {
            addLocations(query);
            query.trace("MultiPointTester="+active+" added locations", true, 2);
        } else {
            query.trace("MultiPointTester is NOP", false, 2);
        }
        return execution.search(query);
    }

    private Location makeLocation(double ns, double ew) {
        Location r = new Location();
        r.setAttribute("latlong");
        r.setGeoCircle(ns, ew, 10.0);
        return r;
    }

    private void addLocations(Query query) {
        Location sunnyvale = makeLocation(37.5, -122.0);
        Location naples = makeLocation(40.8, 14.2);
        OrItem filter = new OrItem();
        filter.addItem(new GeoLocationItem(sunnyvale));
        filter.addItem(new GeoLocationItem(naples));
        QueryTree tree = query.getModel().getQueryTree();
        if (tree.isEmpty()) {
            tree.setRoot(filter);
        } else {
            Item oldroot = tree.getRoot();
            AndItem newtop = new AndItem();
            newtop.addItem(oldroot);
            newtop.addItem(filter);
            tree.setRoot(newtop);
        }
    }
}
