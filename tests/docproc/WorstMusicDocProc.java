// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.document.DocumentPut;
import com.yahoo.docproc.*;

public class WorstMusicDocProc extends SimpleDocumentProcessor {

    public WorstMusicDocProc() {
        System.out.println("WorstMusicDocProc constructor!");
    }

    @Override
    public void process(DocumentPut put) {
        System.out.println("WorstMusicDocProc.process(DocumentPut)");
        put.getDocument().setFieldValue("title", "Worst music ever");
    }

}
