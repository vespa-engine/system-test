// Copyright Vespa.ai. All rights reserved.
package com.yahoo.example.docproc;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.docproc.SimpleDocumentProcessor;

public class WorstMusicDocProc extends SimpleDocumentProcessor {
    public WorstMusicDocProc() {
        System.err.println("WorstMusicDocProc constructor!");
    }

    @Override
    public void process(DocumentPut documentPut) {
	Document document = documentPut.getDocument();
        System.err.println("WorstMusicDocProc.process(DocumentUpdate)");
        document.setFieldValue("title", "Worst music ever");
    }

}
