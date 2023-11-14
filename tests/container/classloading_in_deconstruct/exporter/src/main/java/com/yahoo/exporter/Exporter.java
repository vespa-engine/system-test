// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.exporter;

import java.util.concurrent.Callable;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * @author gjoranv
 */
public class Exporter implements Callable<String> {
    private static final Logger log = Logger.getLogger(Exporter.class.getName());

    @Override
    public String call() {
        return "Successfully called!";
    }

}
