// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.docproc.SimpleDocumentProcessor;
import com.yahoo.docproc.Accesses;
import com.yahoo.docproc.Accesses.Field;

@Accesses(value = { @Accesses.Field(dataType = "String", description = "Foo", name = "banana") })
public class BananaDocProc extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentPut documentPut) {
        Document document = documentPut.getDocument();
        document.setFieldValue("banana", new StringFieldValue(document.getFieldValue("banana") + " Banana"));
    }

}
