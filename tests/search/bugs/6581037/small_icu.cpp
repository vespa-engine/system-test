// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <assert.h>
#include <stdio.h>
#include <string>
#include <unicode/ustring.h>
#include <unicode/coll.h>
#include <unicode/unistr.h>

int main(int, char **)
{
    {
        UErrorCode status = U_ZERO_ERROR;
        icu::Collator *coll = icu::Collator::createInstance(icu::Locale("ar"), status);
        assert(U_SUCCESS(status));
        coll->setStrength(icu::Collator::PRIMARY);

        UChar arabicChars[] = { 0x0627, 0x0644, 0x062c, 0x0632, 0x064a, 0x0631, 0x0629 };
        UChar englishChars[] = { 'A', 'l',  ' ', 'J', 'a', 'z', 'e', 'e', 'r', 'a' };
        icu::UnicodeString arabicTxt(arabicChars, 7);
        icu::UnicodeString englishTxt(englishChars, 10);
        std::string arabicString;
        std::string englishString;
        arabicTxt.toUTF8String(arabicString);
        englishTxt.toUTF8String(englishString);

        int r = coll->compare(arabicTxt, englishTxt);
        fprintf(stdout, "arabic %s compares as %d versus english %s\n", arabicString.c_str(), r, englishString.c_str());
        delete coll;
    }
    {
        UErrorCode status = U_ZERO_ERROR;
        icu::Collator *coll = icu::Collator::createInstance(icu::Locale("ar"), status);
        assert(U_SUCCESS(status));
        coll->setStrength(icu::Collator::PRIMARY);

        UChar chineseChars[] = { 0x767e, 0x5ea6 };
        UChar englishChars[] = { 'B', 'a', 'i', 'd', 'u' };
        icu::UnicodeString chineseTxt(chineseChars, 2);
        icu::UnicodeString englishTxt(englishChars, 5);
        std::string chineseString;
        std::string englishString;
        chineseTxt.toUTF8String(chineseString);
        englishTxt.toUTF8String(englishString);

        int r = coll->compare(chineseTxt, englishTxt);
        fprintf(stdout, "chinese %s compares as %d to english %s\n", chineseString.c_str(), r, englishString.c_str());
        delete coll;
    }
    return 0;
}
