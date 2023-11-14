// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.document.DocumentPut;
import com.yahoo.docproc.*;

public class WorstMusicDocProc extends SimpleDocumentProcessor {

    public WorstMusicDocProc() {
        System.err.println("WorstMusicDocProc constructor!");
    }

    @Override
    public void process(DocumentPut put) {
        System.err.println("WorstMusicDocProc.process(DocumentPut)");
        put.getDocument().setFieldValue("title", "Worst music ever");
    }

}
