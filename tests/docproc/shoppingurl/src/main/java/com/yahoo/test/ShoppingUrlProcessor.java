// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentType;
import com.yahoo.document.DocumentUpdate;
import com.yahoo.document.Field;
import com.yahoo.document.update.*;
import com.yahoo.docproc.*;
import com.yahoo.document.datatypes.*;
import com.yahoo.document.DataType;
import java.util.List;
import java.util.ArrayList;

public class ShoppingUrlProcessor extends SimpleDocumentProcessor {

    ShoppingUrlCompression coder = new ShoppingUrlCompression();

    private Array<ByteFieldValue> compressString(String input) {
        byte[] cstr = coder.compressString(input);
        Array<ByteFieldValue> val = new Array<ByteFieldValue>(DataType.getArray(DataType.BYTE));
        for (byte b : cstr) {
            val.add(new ByteFieldValue(b));
        }
        return val;
    }

    private Field offerUrl(DocumentType dt) {
        return dt.getField("ourl");
    }

    private Field comprUrl(DocumentType dt) {
        return dt.getField("comprurl");
    }

    @Override
    public void process(DocumentPut put) {
        Document document = put.getDocument();
        DocumentType dt = document.getDataType();
        Field origField = offerUrl(dt);
        Field cmprField = comprUrl(dt);
        FieldValue ourl = document.getFieldValue(origField);
        if (ourl instanceof StringFieldValue) {
            document.setFieldValue(cmprField, compressString(((StringFieldValue)ourl).getString()));
        }
    }

    public void process(DocumentUpdate documentUpd) {
        DocumentType dt = documentUpd.getDocumentType();
        Field origField = offerUrl(dt);
        Field cmprField = comprUrl(dt);
	List<FieldUpdate> replacements = new ArrayList<>();
        for (FieldUpdate fup : documentUpd.fieldUpdates()) {
            if (fup.getField().equals(origField)) {
                FieldUpdate av = null;
                int conv = 0;
                for (ValueUpdate vu : fup.getValueUpdates()) {
		    Object o = vu.getValue();
                    if (vu instanceof AssignValueUpdate && o instanceof StringFieldValue) {
                        Array<ByteFieldValue> val = compressString(o.toString());
                        av = FieldUpdate.createAssign(cmprField, val);
                        ++conv;
		    } else {
			throw new IllegalArgumentException("expected assign String update, got: "+vu);
		    }
                }
		if (conv != 1) {
		    throw new IllegalArgumentException("expected exactly 1 assign update, got: "+fup);
		}
                documentUpd.removeFieldUpdate(fup.getField());
		replacements.add(av);
            }
        }
	replacements.forEach(replacement -> documentUpd.addFieldUpdate(replacement));
    }
}
