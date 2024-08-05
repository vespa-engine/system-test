// Copyright Vespa.ai. All rights reserved.
package test;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentId;
import com.yahoo.document.DocumentType;
import com.yahoo.document.DocumentUpdate;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.document.update.FieldUpdate;

/**
 * @author Simon Thoresen Hult
 */
class Documents {

    public static Document newDocument(DocumentType type, String docId, String fieldValue) {
        Document doc = new Document(type, new DocumentId(docId));
        doc.setFieldValue("my_str", fieldValue);
        return doc;
    }

    public static DocumentUpdate newUpdate(DocumentType type, String docId, String fieldValue) {
        DocumentUpdate upd = new DocumentUpdate(type, new DocumentId(docId));
        upd.addFieldUpdate(FieldUpdate.createAssign(type.getField("my_str"), new StringFieldValue(fieldValue)));
        return upd;
    }
}
