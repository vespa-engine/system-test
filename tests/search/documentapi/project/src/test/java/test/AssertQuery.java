// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package test;

import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import java.io.IOException;
import java.net.URL;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

/**
 * @author Simon Thoresen Hult
 */
class AssertQuery {

    public static void assertQuery(String documentId, String fieldName, String expectedFieldValue) {
        Element result;
        try {
            result = doQuery();
        } catch (IOException | ParserConfigurationException | SAXException e) {
            throw new AssertionError(e);
        }
        Element hit = getHit(result, documentId);
        if (expectedFieldValue == null) {
            assertNull(hit);
        } else {
            assertNotNull(hit);
            assertEquals(expectedFieldValue, getFieldValue(hit, fieldName));
        }
    }

    private static Element getHit(Element result, String documentId) {
        NodeList hits = result.getElementsByTagName("hit");
        for (int i = 0, len = hits.getLength(); i < len; ++i) {
            Element hit = (Element)hits.item(i);
            if (getFieldValue(hit, "documentid").equals(documentId)) {
                return hit;
            }
        }
        return null;
    }

    private static String getFieldValue(Element hit, String fieldName) {
        NodeList fields = hit.getElementsByTagName("field");
        for (int i = 0, len = fields.getLength(); i < len; ++i) {
            Element field = (Element)fields.item(i);
            if (field.getAttribute("name").equals(fieldName)) {
                return field.getTextContent();
            }
        }
        return null;
    }

    private static Element doQuery() throws IOException, ParserConfigurationException, SAXException {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        DocumentBuilder builder = factory.newDocumentBuilder();
        return builder.parse(new URL("http://localhost:4080/search/?query=sddocname:test")
                                     .openConnection()
                                     .getInputStream()).getDocumentElement();
    }
}
