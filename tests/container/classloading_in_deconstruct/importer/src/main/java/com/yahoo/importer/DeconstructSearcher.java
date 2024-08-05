// Copyright Vespa.ai. All rights reserved.
package com.yahoo.importer;

import java.util.concurrent.Callable;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.yahoo.search.*;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

/**
 * A searcher loading a not previously loaded class in its deconstruct method.
 *
 * @author gjoranv
 */
public class DeconstructSearcher extends Searcher {
    private static final Logger log = Logger.getLogger(DeconstructSearcher.class.getName());

    @Override
    public Result search(Query query, Execution execution) {
        query.trace("Running simpleSearcher", true, 3);
        Result result = execution.search(query); // Pass on to the next searcher to get results
        Hit hit = new Hit("test");
        hit.setField("message", "Hello, World!");
        result.hits().add(hit);
        query.trace("SimpleSearcher: result set: " + result.toString(), true, 3);
        return result;
    }

    @Override
    @SuppressWarnings({ "unchecked" })
    public void deconstruct() {
        try {
            Class<?> callableClass = this.getClass().getClassLoader().loadClass("com.yahoo.exporter.Exporter");
            Callable<String> callable = (Callable<String>) callableClass.getDeclaredConstructor().newInstance();
            String message = callable.call();
            log.log(Level.INFO, "Successfully retrieved message from exporter in deconstruct: " + message);
        } catch (ClassNotFoundException | NullPointerException e) {
            log.log(Level.SEVERE, "Class not found when deconstructing importer.", e);
        } catch (Throwable t) {
            log.log(Level.SEVERE, "Got unexpected throwable when deconstructing importer.", t);
        }
    }

}
