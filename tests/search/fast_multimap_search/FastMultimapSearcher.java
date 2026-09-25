// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.component.chain.dependencies.After;
import com.yahoo.component.chain.dependencies.Before;
import com.yahoo.prelude.query.CompositeItem;
import com.yahoo.prelude.query.ExactStringItem;
import com.yahoo.prelude.query.IntItem;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.Limit;
import com.yahoo.prelude.query.QueryCanonicalizer;
import com.yahoo.prelude.query.SameElementItem;
import com.yahoo.prelude.query.StringRangeItem;
import com.yahoo.prelude.query.TermItem;
import com.yahoo.prelude.query.WordItem;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.search.searchchain.PhaseNames;

import java.util.Map;
import java.util.regex.Pattern;

/**
 * Rewrites sameElement on a multimap (an array of key-value structs) to a single lookup in a
 * synthetic key-value attribute, built by the indexing script of the schema. Adapted from the
 * FastMapSearcher of Vespa, which does the same for maps with 'map: fast-search'.
 *
 * Set the query property fastmultimap.disable to run the regular sameElement instead.
 */
@Before(QueryCanonicalizer.queryCanonicalization)
@After(PhaseNames.TRANSFORMED_QUERY)
public class FastMultimapSearcher extends Searcher {

    /** DEL cannot occur in a key, and separates the key from the value in the synthetic attribute. */
    private static final String KEY_VALUE_SEPARATOR = "\u007f";

    private enum ValueType { STRING, INT, FLOAT }

    private record Multimap(String keyField, String valueField, ValueType valueType, String keyValueAttribute) {}

    /** The multimaps of the schema, by field name. Must agree with the indexing scripts there. */
    private static final Map<String, Multimap> multimaps = Map.of(
            "string_multimap", new Multimap("string_string_pair_key", "string_string_pair_value", ValueType.STRING, "string_multimap_keyvalue"),
            "int_multimap", new Multimap("string_int_pair_key", "string_int_pair_value", ValueType.INT, "int_multimap_keyvalue"),
            "float_multimap", new Multimap("string_float_pair_key", "string_float_pair_value", ValueType.FLOAT, "float_multimap_keyvalue"));

    @Override
    public Result search(Query query, Execution execution) {
        if ( ! query.properties().getBoolean("fastmultimap.disable")) {
            Item root = query.getModel().getQueryTree().getRoot();
            Item newRoot = rewrite(root);
            if (newRoot != root) {
                query.getModel().getQueryTree().setRoot(newRoot);
            }
            query.trace("FastMultimapSearcher: query after rewrite: " + newRoot, true, 2);
        }
        return execution.search(query);
    }

    private Item rewrite(Item item) {
        if (item instanceof SameElementItem sameElement && multimaps.containsKey(sameElement.getFieldName())) {
            TermItem rewritten = tryMakeFastMultimapItem(sameElement, multimaps.get(sameElement.getFieldName()));
            if (rewritten != null) {
                return rewritten;
            }
        }
        if (item instanceof CompositeItem composite) {
            for (int i = 0; i < composite.getItemCount(); i++) {
                Item child = composite.getItem(i);
                Item newChild = rewrite(child);
                if (newChild != child) {
                    composite.setItem(i, newChild);
                }
            }
        }
        return item;
    }

    /**
     * Returns the single lookup term equivalent to the given sameElement, or null if the
     * sameElement cannot be expressed as one. A single value becomes a word lookup, a range
     * becomes a lexical range, both on the synthetic attribute.
     */
    private TermItem tryMakeFastMultimapItem(SameElementItem sameElement, Multimap multimap) {
        if ( ! sameElement.getElementFilter().isEmpty() || sameElement.getItemCount() != 2) {
            return null;
        }
        Item first = sameElement.getItem(0);
        Item second = sameElement.getItem(1);
        TermItem keyItem = termWithIndex(multimap.keyField(), first, second);
        TermItem valueItem = termWithIndex(multimap.valueField(), first, second);
        if (keyItem == null || valueItem == null) {
            return null;
        }
        String key = getString(keyItem);
        if (key == null) {
            return null;
        }
        return switch (multimap.valueType()) {
            case STRING -> makeStringItem(key, valueItem, multimap.keyValueAttribute());
            case INT -> makeIntItem(key, valueItem, multimap.keyValueAttribute());
            case FLOAT -> makeFloatItem(key, valueItem, multimap.keyValueAttribute());
        };
    }

    /** Returns the word of a word term, or null if the term is not one. */
    private static String getString(TermItem term) {
        if (term.getClass() == WordItem.class || term instanceof ExactStringItem) {
            return ((WordItem) term).getWord();
        }
        return null;
    }

    /** Returns the first of the two items which is a term with the given index name, or null. */
    private static TermItem termWithIndex(String indexName, Item first, Item second) {
        if (first instanceof TermItem term && indexName.equals(term.getIndexName())) {
            return term;
        }
        if (second instanceof TermItem term && indexName.equals(term.getIndexName())) {
            return term;
        }
        return null;
    }

    // ---------------------------------------------------------------------------------------------
    // string values, which are not encoded
    // ---------------------------------------------------------------------------------------------

    /** Only a single value is supported: a string range is left to the regular sameElement. */
    private static TermItem makeStringItem(String key, TermItem valueItem, String attribute) {
        String value = getString(valueItem);
        if (value == null) {
            return null;
        }
        return new WordItem(key + KEY_VALUE_SEPARATOR + value, attribute, false);
    }

    // ---------------------------------------------------------------------------------------------
    // int values, encoded like the exhex8encode indexing expression
    // ---------------------------------------------------------------------------------------------

    private static TermItem makeIntItem(String key, TermItem valueItem, String attribute) {
        Limit fromLimit;
        Limit toLimit;
        if (valueItem instanceof IntItem intItem) {
            if (intItem.getHitLimit() != 0) {
                return null; // a hit limit counts entries in the value attribute, not the synthetic one
            }
            fromLimit = intItem.getFromLimit();
            toLimit = intItem.getToLimit();
        } else if (valueItem.getClass() == WordItem.class) {
            try {
                int value = Integer.parseInt(((WordItem) valueItem).getWord().trim());
                fromLimit = toLimit = new Limit(value, true);
            } catch (NumberFormatException e) {
                return null; // not an int: fall back to the regular sameElement
            }
        } else {
            return null;
        }
        Integer from = toIntBound(fromLimit, Integer.MIN_VALUE);
        Integer to = toIntBound(toLimit, Integer.MAX_VALUE);
        if (from == null || to == null) {
            return null;
        }
        // An unbounded limit is included by the backend whether the limit is inclusive or not.
        boolean fromInclusive = fromLimit.isInfinite() || fromLimit.isInclusive();
        boolean toInclusive = toLimit.isInfinite() || toLimit.isInclusive();
        if (fromInclusive && toInclusive && from.equals(to)) {
            return new WordItem(intTerm(key, from), attribute, false);
        }
        return new StringRangeItem(intTerm(key, from), fromInclusive, intTerm(key, to), toInclusive,
                                   attribute, false, null);
    }

    /**
     * Returns the int to encode for the given range endpoint, using the given value when the
     * endpoint is unbounded, or null if the endpoint has no exact int form.
     */
    private static Integer toIntBound(Limit limit, int whenInfinite) {
        if (limit.isInfinite()) {
            return whenInfinite;
        }
        int asInt = limit.number().intValue();
        if (limit.number().doubleValue() != (double) asInt) {
            return null; // not an int endpoint: fall back to the regular sameElement
        }
        return asInt;
    }

    /** Biased by 2^31, such that the hex strings sort in the same order as the values. */
    private static String intTerm(String key, int value) {
        return key + KEY_VALUE_SEPARATOR + String.format("%08x", value ^ Integer.MIN_VALUE);
    }

    // ---------------------------------------------------------------------------------------------
    // float values, encoded like the exhex8floatencode indexing expression
    // ---------------------------------------------------------------------------------------------

    private static final Pattern decimalNumber = Pattern.compile("[+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?");

    /**
     * Each endpoint is rounded to the nearest float, like the backend does for a float attribute.
     * Since -0.0 and 0.0 are equal as numbers but not as encoded strings, a zero endpoint is encoded
     * as the zero which makes the range include or exclude both zeros.
     */
    private static TermItem makeFloatItem(String key, TermItem valueItem, String attribute) {
        Limit fromLimit;
        Limit toLimit;
        if (valueItem instanceof IntItem intItem) {
            if (intItem.getHitLimit() != 0) {
                return null; // a hit limit counts entries in the value attribute, not the synthetic one
            }
            fromLimit = intItem.getFromLimit();
            toLimit = intItem.getToLimit();
        } else if (valueItem.getClass() == WordItem.class) {
            String word = ((WordItem) valueItem).getWord().trim();
            if ( ! decimalNumber.matcher(word).matches()) {
                return null; // not a number: fall back to the regular sameElement
            }
            fromLimit = toLimit = new Limit(Double.parseDouble(word), true);
        } else {
            return null;
        }
        boolean fromInclusive = fromLimit.isInfinite() || fromLimit.isInclusive();
        boolean toInclusive = toLimit.isInfinite() || toLimit.isInclusive();
        float from = toFloatBound(fromLimit, true, fromInclusive);
        float to = toFloatBound(toLimit, false, toInclusive);
        if (Float.isNaN(from) || Float.isNaN(to)) {
            return null; // matches nothing in the backend: fall back to the regular sameElement
        }
        if (fromInclusive && toInclusive && Float.floatToRawIntBits(from) == Float.floatToRawIntBits(to)) {
            return new WordItem(floatTerm(key, from), attribute, false);
        }
        return new StringRangeItem(floatTerm(key, from), fromInclusive, floatTerm(key, to), toInclusive,
                                   attribute, false, null);
    }

    /**
     * Returns the float endpoint of a range with the given limit. An unbounded limit becomes the
     * infinity in its direction. A zero endpoint becomes the zero on the outside of the range when
     * inclusive, and on the inside when exclusive, so that either both zeros are matched or neither is.
     */
    private static float toFloatBound(Limit limit, boolean isLower, boolean inclusive) {
        if (limit.isInfinite()) {
            return isLower ? Float.NEGATIVE_INFINITY : Float.POSITIVE_INFINITY;
        }
        float bound = (float) limit.number().doubleValue(); // via double, like the backend
        if (bound == 0.0f) {
            bound = (isLower == inclusive) ? -0.0f : 0.0f;
        }
        return bound;
    }

    /**
     * Positive values get the sign bit set, while negative values get all bits inverted, such
     * that the hex strings sort in the same order as the values, also across zero.
     */
    private static String floatTerm(String key, float value) {
        int bits = Float.floatToRawIntBits(value);
        bits ^= (bits < 0) ? -1 : Integer.MIN_VALUE;
        return key + KEY_VALUE_SEPARATOR + String.format("%08x", bits);
    }

}
