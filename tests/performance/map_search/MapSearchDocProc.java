// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.docproc.SimpleDocumentProcessor;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.Field;
import com.yahoo.document.datatypes.Array;
import com.yahoo.document.datatypes.IntegerFieldValue;
import com.yahoo.document.datatypes.MapFieldValue;
import com.yahoo.document.datatypes.StringFieldValue;

/**
 * Document processor for the map_search performance test.
 *
 * For each map<string,int> field (kv_5, kv_25, kv_125) it fills the companion
 * array<string> field "<name>_combined_attr" with one "key#value" string per map
 * entry, where value is formatted as an 8-digit unsigned hex number, so the
 * combined key/value can be searched as a single attribute.
 */
public class MapSearchDocProc extends SimpleDocumentProcessor {

    private final String[] mapNames = { "kv_5", "kv_25", "kv_125" };

    @Override
    public void process(DocumentPut put) {
        Document document = put.getDocument();
        for (var mapName : mapNames) {
            var mapField = document.getFieldValue(mapName);
            if (mapField instanceof MapFieldValue<?, ?> mapValue) {
                Field combinedField = document.getField(mapName + "_combined_attr");
                @SuppressWarnings("unchecked")
                Array<StringFieldValue> combined =
                        (Array<StringFieldValue>) combinedField.getDataType().createFieldValue();
                for (var entry : mapValue.entrySet()) {
                    String key = ((StringFieldValue) entry.getKey()).getString();
                    int value = ((IntegerFieldValue) entry.getValue()).getInteger();
                    combined.add(new StringFieldValue(key + "#" + String.format("%08x", value)));
                }
                document.setFieldValue(combinedField, combined);
            }
        }
    }

}
