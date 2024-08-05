// Copyright Vespa.ai. All rights reserved.
import com.yahoo.document.Document;
import com.yahoo.document.DocumentId;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentRemove;
import com.yahoo.document.DocumentType;
import com.yahoo.document.DocumentUpdate;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.document.update.FieldUpdate;
import com.yahoo.document.update.ValueUpdate;
import com.yahoo.documentapi.DocumentAccess;
import com.yahoo.documentapi.SyncParameters;
import com.yahoo.documentapi.SyncSession;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/**
 * System test accessing the wasFound flag of update and remove replies.
 *
 * @author Magnar Nedland
 */
public class WasFoundTest {
    private DocumentId docId = new DocumentId("id:test:test::foo");
    private DocumentAccess access;
    private SyncSession session;
    private DocumentType type;
    private Document doc;

    @Before
    public void setUp() {
        access = DocumentAccess.createForNonContainer();
        session = access.createSyncSession(new SyncParameters.Builder().build());
        type = access.getDocumentTypeManager().getDocumentType("test");
        doc = new Document(type, docId);
        doc.setFieldValue("fruit", "coconut");
        session.remove(new DocumentRemove(docId));
    }

    @After
    public void tearDown() {
        access.shutdown();
    }

    @Test
    public void require_that_was_found_flag_is_set_in_update()
        throws Exception {
        DocumentUpdate docUpdate = createUpdate();

        assertFalse(session.update(docUpdate));
        session.put(new DocumentPut(doc));
        assertTrue(session.update(docUpdate));
    }

    private DocumentUpdate createUpdate() {
        DocumentUpdate docUpdate = new DocumentUpdate(type, docId);
        FieldUpdate fieldUpdate = FieldUpdate.create(type.getField("fruit"));
        ValueUpdate valueUpdate = ValueUpdate.createAssign(new StringFieldValue("banana"));
        fieldUpdate.addValueUpdate(valueUpdate);
        docUpdate.addFieldUpdate(fieldUpdate);
        return docUpdate;
    }

    @Test
    public void require_that_was_found_flag_is_set_in_remove()
            throws Exception {
        assertFalse(session.remove(new DocumentRemove(docId)));
        session.put(new DocumentPut(doc));
        assertTrue(session.remove(new DocumentRemove(docId)));
        assertFalse(session.remove(new DocumentRemove(docId)));
    }
}
