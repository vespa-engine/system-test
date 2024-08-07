// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.docproc.SimpleDocumentProcessor;
import com.yahoo.document.DocumentPut;

public class MyProcessor extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentPut put) {
        System.out.println("PROCESSED: " + put.getId());
    }

}
