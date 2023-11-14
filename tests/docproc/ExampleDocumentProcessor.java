// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;
import com.yahoo.document.DataType;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentOperation;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.Field;
import com.yahoo.document.datatypes.FieldValue;
import com.yahoo.document.datatypes.StringFieldValue;

/**
 * A document processor that uppercases all string fields in Documents.
 *
 * @author Einar M R Rosenvinge
 */
public class ExampleDocumentProcessor extends DocumentProcessor {

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (op instanceof DocumentPut) {
                Document document = ((DocumentPut)op).getDocument();
                for (Field f : document.getDataType().fieldSet()) {
                    if (f.getDataType() == DataType.STRING) {
                        FieldValue value = document.getFieldValue(f);
                        if (value != null) {
                            StringFieldValue stringVal = (StringFieldValue) value;
                            stringVal = new StringFieldValue(stringVal.getString().toUpperCase());
                            document.setFieldValue(f, stringVal);
                        }
                    }
                }
            }
        }
        return Progress.DONE;
    }

}
