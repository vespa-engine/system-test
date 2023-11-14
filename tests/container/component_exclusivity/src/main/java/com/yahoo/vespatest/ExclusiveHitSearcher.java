// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.io.IOException;
import java.lang.Thread;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.logging.Logger;

import com.yahoo.concurrent.classlock.ClassLock;
import com.yahoo.concurrent.classlock.ClassLocking;
import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.vespatest.ExclusiveHitConfig;
import com.yahoo.component.ComponentId;

public class ExclusiveHitSearcher extends Searcher {
    private final static Logger log = Logger.getLogger(ExclusiveHitSearcher.class.getName());
    private final static Path testFile = Paths.get("/tmp/exclusivity_test.txt");

    final ExclusiveHitConfig config;
    final Thread thread;
    final AtomicBoolean terminated = new AtomicBoolean(false);
    ClassLock lock;

    public ExclusiveHitSearcher(ComponentId id, ExclusiveHitConfig config, ClassLocking locking) {
        super(id);
        this.config = config;

        thread = new Thread(() -> {
            log(config.compId(), "Waiting for lock...");
            lock = locking.lock(ExclusiveHitSearcher.class);
            log(config.compId(), "Lock acquired, staring thread");

            while (! terminated.get()) {
                appendTestFile(config.compId());
            }
        });
        thread.start();
    }

    public @Override Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        Hit hit = new Hit("id");
        hit.setField("component_id", config.compId());
        hit.setField("exclusivity_file", readTestFile());
        result.hits().add(hit);
        return result;
    }

    public @Override void deconstruct() {
        log(config.compId(), "Deconstruct called");
        terminated.set(true);
        try {
            thread.join();
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
        log(config.compId(), "Deconstruct complete");
        lock.close();
        log(config.compId(), "Lock released");
    }

    private static void appendTestFile(String str) {
        try {
            Files.write(testFile, str.getBytes(), StandardOpenOption.APPEND, StandardOpenOption.CREATE);
            Thread.sleep(100);
        } catch (Exception e) {
            throw new RuntimeException("Could not write to file " + testFile.toString(), e);
        }
    }

    private static String readTestFile() {
        try {
            return new String(Files.readAllBytes(testFile));
        } catch (Exception e) {
            throw new RuntimeException("Could not read file " + testFile.toString(), e);
        }
    }

    private static void log(String id, String message) {
        log.info(ExclusiveHitSearcher.class.getSimpleName() + "-" + id + ": " + message);
    }
}