// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.importer;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.component.Component;
import com.yahoo.exporter.ExporterSearcher;
import com.yahoo.exporter.config.ExporterConfig;
import com.yahoo.importer.config.ImporterConfig;

public class ImporterSearcher extends ExporterSearcher {

    private final String myTitle;

    public ImporterSearcher(ExporterConfig exporterConfig, ImporterConfig config) {
        super(exporterConfig);
        myTitle = config.exampleString();
    }

    @Override
    public Result search(Query query, Execution execution) {
        query.properties().set("query", query.properties().getString("query") + " AND demo");
        Result result = super.search(query, execution);
        return addHit(myTitle, result);
    }
}
