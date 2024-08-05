// Copyright Vespa.ai. All rights reserved.
package test;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentId;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentRemove;
import com.yahoo.document.DocumentType;
import com.yahoo.document.DocumentUpdate;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.documentapi.DocumentAccess;
import com.yahoo.documentapi.SyncParameters;
import com.yahoo.documentapi.SyncSession;
import org.junit.After;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static test.AssertQuery.assertQuery;
import static test.Documents.newDocument;
import static test.Documents.newUpdate;

/**
 * @author Simon Thoresen Hult
 */
public class SyncSessionTest {

    private final DocumentAccess access = DocumentAccess.createForNonContainer();
    private final SyncSession session = access.createSyncSession(new SyncParameters.Builder().build());

    @Test
    public void requireThatSyncSessionWorks() throws Exception {
        DocumentType type = access.getDocumentTypeManager().getDocumentType("test");
        assertPut(newDocument(type, "id:tenant:test::foo", "bar"));
        assertGet("id:tenant:test::foo", "bar");

        assertUpdate(newUpdate(type, "id:tenant:test::foo", "baz"));
        assertGet("id:tenant:test::foo", "baz");

        assertRemove("id:tenant:test::foo");
        assertGet("id:tenant:test::foo", null);
    }

    @After
    public void after() {
        session.destroy();
        access.shutdown();
    }

    private void assertPut(Document doc) {
        System.out.println("Put '" + doc.getId() + "'..");
        session.put(new DocumentPut(doc));
    }

    private void assertUpdate(DocumentUpdate upd) {
        System.out.println("Update '" + upd.getId() + "'..");
        assertTrue(session.update(upd));
    }

    private void assertRemove(String docId) {
        System.out.println("Remove '" + docId + "'..");

        assertTrue(session.remove(new DocumentRemove(new DocumentId(docId))));
    }

    private void assertGet(String docId, String expectedFieldValue) {
        System.out.println("Get '" + docId + "'..");
        Document doc = session.get(new DocumentId(docId));
        System.out.println(doc);
        if (expectedFieldValue == null) {
            assertNull(doc);
        } else {
            assertNotNull(doc);
            assertEquals(new StringFieldValue(expectedFieldValue), doc.getFieldValue("my_str"));
        }
    }
}
