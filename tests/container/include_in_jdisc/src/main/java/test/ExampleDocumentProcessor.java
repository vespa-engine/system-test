// Copyright Vespa.ai. All rights reserved.
package test;

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

    private final FooComponent fooComp;
    private final BarComponent barComp;
    
    @com.google.inject.Inject
    public ExampleDocumentProcessor(FooComponent fooComp, BarComponent barComp) {
        this.fooComp = fooComp;
        this.barComp = barComp;
    }
    
    @Override
    public Progress process(Processing processing) {
        System.out.println("FOO");
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (op instanceof DocumentPut) {
                Document document = ((DocumentPut)op).getDocument();
                for (Field f : document.getDataType().fieldSet()) {
                    if (f.getDataType() == DataType.STRING) {
                        FieldValue value = document.getFieldValue(f);
                        if (value != null) {
                            StringFieldValue stringVal = (StringFieldValue) value;
                            stringVal = new StringFieldValue(fooComp.foo()+" "+barComp.bar());
                            document.setFieldValue(f, stringVal);
                        }
                    }
                }
            }
        }
        return Progress.DONE;
    }
}
