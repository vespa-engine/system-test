// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.docproc.SimpleDocumentProcessor;

public class TerribleMusicDocProc extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentPut documentPut) {
        Document document = documentPut.getDocument();
        document.setFieldValue("title", "Terrible music");
    }

}
