// Copyright Vespa.ai. All rights reserved.
import com.ibm.icu.text.Collator;
import com.ibm.icu.util.ULocale;

public class SmallIcuTest {
    private static void testArabic() {
	String locale = "ar";
        Collator collator;
        ULocale uloc;
        try {
            uloc = new ULocale(locale);
        } catch (Throwable e) {
            throw new RuntimeException("ULocale(" + locale + ") failed with exception " + e.toString());
        }
        try {
            collator = Collator.getInstance(uloc);
            if (collator == null) {
                throw new RuntimeException("No collator available for: " + locale);
            }
        } catch (Throwable e) {
            throw new RuntimeException("Collator.getInstance(ULocale(" + locale + ")) failed with exception " + e.toString());
        }
        collator.setStrength(Collator.PRIMARY);
        String arabicTxt = "\u0627\u0644\u062c\u0632\u064a\u0631\u0629";
        String englishTxt = "Al Jazeera";
        int r = collator.compare(arabicTxt, englishTxt);
        System.out.println("arabic " + arabicTxt + " compares as " + r + " versus english " + englishTxt);
    }
    private static void testChinese() {
	String locale = "zh";
        Collator collator;
        ULocale uloc;
        try {
            uloc = new ULocale(locale);
        } catch (Throwable e) {
            throw new RuntimeException("ULocale(" + locale + ") failed with exception " + e.toString());
        }
        try {
            collator = Collator.getInstance(uloc);
            if (collator == null) {
                throw new RuntimeException("No collator available for: " + locale);
            }
        } catch (Throwable e) {
            throw new RuntimeException("Collator.getInstance(ULocale(" + locale + ")) failed with exception " + e.toString());
        }
        collator.setStrength(Collator.PRIMARY);
        String chineseTxt = "\u767e\u5ea6";
        String englishTxt = "Baidu";
        int r = collator.compare(chineseTxt, englishTxt);
        System.out.println("chinese " + chineseTxt + " compares as " + r + " versus english " + englishTxt);
    }
    public static void main(String[] argv) {
        testArabic();
        testChinese();
    }
}
