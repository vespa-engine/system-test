package com.yahoo.vespatest;

import java.util.logging.Level;
import java.util.logging.Logger;

import com.yahoo.search.*;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

/**
 * A searcher loading a not previously loaded class in its deconstruct method.
 */
public class DeconstructSearcher extends Searcher {
    private static final Logger log = Logger.getLogger(DeconstructSearcher.class.getName());

    private final String response;

    public DeconstructSearcher(ResponseConfig config) {
        response = config.response();
    }

    @Override
    public Result search(Query query, Execution execution) {
        query.trace("Running simpleSearcher", true, 3);
        Result result = execution.search(query); // Pass on to the next searcher to get results
        Hit hit = new Hit("test");
        hit.setField("message", response);
        result.hits().add(hit);
        query.trace("SimpleSearcher: result set: " + result.toString(), true, 3);
        return result;
    }

    @Override
    public void deconstruct() {
        try {
            Class<?> causesException = this.getClass().forName("com.yahoo.docproc.DocumentProcessor");
        } catch (ClassNotFoundException e) {
            log.log(Level.SEVERE, "Class not found when deconstructing searcher", e);
        }
    }

}
