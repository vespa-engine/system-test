// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.vespatest.FilesConfig;
import com.yahoo.component.ComponentId;

import java.io.*;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;
import java.util.List;
import java.util.ArrayList;

public class FileSearcher extends Searcher {
    private Path dir;

    public FileSearcher(ComponentId id, FilesConfig config) {
        dir = config.dirWithFiles();
    }

    public @Override Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        for (File f : dir.toFile().listFiles()) {
            Hit hit = new Hit(f.getAbsolutePath());
            hit.setField("title", readFile(f));
            result.hits().add(hit);
        }
        return result;
    }

    private String readFile(File file) {
        StringBuilder ret = new StringBuilder();
        try {
            LineNumberReader reader = new LineNumberReader(new InputStreamReader(new FileInputStream(file), "UTF-8"));
            try {
                String line;
                while ((line = reader.readLine()) != null) {
                    ret.append(line).append("\n");
                }
            } finally {
                reader.close();
            }
        } catch (IOException e) {
            throw new RuntimeException("IOException: ", e);
        }
        return ret.toString();
    }

}
