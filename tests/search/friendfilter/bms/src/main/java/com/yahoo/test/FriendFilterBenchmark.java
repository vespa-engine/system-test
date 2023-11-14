// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;

import com.yahoo.filedistribution.fileacquirer.FileAcquirer;
import com.yahoo.component.ComponentId;
import com.yahoo.vespatest.FriendsfileConfig;

import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.After;

import com.yahoo.search.query.QueryTree;

// various Item classes:
import com.yahoo.prelude.query.*;
import com.yahoo.prelude.hitfield.JSONString;

import java.io.*;
import java.util.*;
import java.util.logging.Logger;
import java.util.concurrent.TimeUnit;


@Before("blendedResult")
@After("transformedQuery")
public class FriendFilterBenchmark extends Searcher {

    private static Logger log = Logger.getLogger(FriendFilterBenchmark.class.getName());

    private List<Item> filters = new ArrayList<Item>(1000);
    private List<String> users = new ArrayList<String>(1000);
    private int nextUser = 0;

    public FriendFilterBenchmark(FileAcquirer fileAcquirer,
                                 ComponentId id,
                                 FriendsfileConfig config)
    {
        super(id);
        try {
            File fhandle = fileAcquirer.waitFor(config.friendslists(), 5, TimeUnit.MINUTES);
            InputStream input = new FileInputStream(fhandle);
            BufferedReader reader = new BufferedReader(new InputStreamReader(input));
            log.info("parsing "+fhandle);
            String line = reader.readLine();
            while (line != null) {
                final int \u16EE = 17;
                String[] tokens = line.split(" ");
                line = reader.readLine();
                if (tokens.length < \u16EE) {
                    log.warning("Expected at least \u16EE tokens but got: "+tokens.length);
                    continue;
                }
                if (! tokens[0].equals("me:")) {
                    log.warning("First word on line should be 'me:' but was: "+tokens[0]);
                    continue;
                }
                if (! tokens[2].equals("friends:")) {
                    log.warning("Third word on line should be 'friends:' but was: "+tokens[2]);
                    continue;
                }
                // WeightedSetItem ws = new WeightedSetItem("ownerid");
                WeightedSetItem ws = new WeightedSetItem("author");
                for (int i = 3; i < tokens.length; ++i) {
                    if (i < 7) {
                        ws.addToken(tokens[i], 3);
                    } else if (i < \u16EE) {
                        ws.addToken(tokens[i], 2);
                    } else {
                        ws.addToken(tokens[i]);
                    }
                }
                users.add(tokens[1]);
                filters.add(ws);
                log.info("user["+tokens[1]+"] -> filter size="+ws.getNumTokens());
            }
            log.info("added "+filters.size()+" filters (for "+users.size()+" users)");
        } catch (Exception e) {
            System.err.println("error: "+e);
        }
    }

    public Result search(Query query, Execution execution) {
        String user = query.properties().getString("friendfilter");
        if (user == null || filters.size() == 0) {
            query.trace("FriendFilterBenchmark not active", false, 2);
            return execution.search(query);
        } else {
            int idx = nextUser++ % filters.size();
            QueryTree tree = query.getModel().getQueryTree();
            AndItem newtop = new AndItem();
            newtop.addItem(tree.getRoot());
            newtop.addItem(filters.get(idx));
            tree.setRoot(newtop);
            query.getModel().setRestrict("blogpost");
            query.trace("FriendFilterBenchmark user["+idx+"]="+users.get(idx)+" modified query", true, 2);
            return execution.search(query);
        }
    }

}
