// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.text.Utf8;
import java.util.zip.*;

public class ShoppingUrlCompression {

    private static byte[] dictionary;

    public ShoppingUrlCompression() {}

    byte[] compressBytes(byte[] bytes) {
        Deflater compresser = new Deflater();
        compresser.setDictionary(dictionary);
        compresser.setInput(bytes);
        compresser.finish();
        byte[] tmp = new byte[bytes.length * 2 + 1000];
        int len = compresser.deflate(tmp);
        byte[] out = new byte[len];
        System.arraycopy(tmp, 0, out, 0, len);
        return out;
    }

    byte[] decompressBytes(byte[] compr) throws java.util.zip.DataFormatException {
        Inflater decompresser = new Inflater();
        decompresser.setInput(compr);
        byte[] tmp = new byte[compr.length * 10 + 1000];
        int len = decompresser.inflate(tmp);
        if (len == 0 && decompresser.needsDictionary()) {
            decompresser.setDictionary(dictionary);
            len = decompresser.inflate(tmp);
        }
        decompresser.end();
        byte[] out = new byte[len];
        System.arraycopy(tmp, 0, out, 0, len);
        return out;
    }

    public byte[] compressString(String input) {
        byte[] strbytes = Utf8.toBytes(input);
        return compressBytes(strbytes);
    }

    public String decompressString(byte[] input) throws java.util.zip.DataFormatException {
        byte[] uncompr = decompressBytes(input);
        return Utf8.toString(uncompr);
    }

    private static String[] dict_urls = {
        "http://yahooshopping.pgpartner.com/rd.php?r=6202&amp;m=32000",
        "026&amp;q=n&amp;priceret=631.33&amp;pg=~~2&amp;k=164e96fc10f",
        "17edf01b54e121432ffcf&amp;source=feed&amp;url=http%3A%2F%2Ft",
        "racking%2Esearchmarketing%2Ecom%2Fclick%2Easp%3Faid%3D209972",
        "234&amp;st=feed&amp;mt=~~~~~~~~y~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=17294&amp;m=7449",
        "38476&amp;q=n&amp;priceret=106.20&amp;pg=~~3&amp;k=74505f4c7",
        "28caba12d975a246c1bb3c5&amp;source=feed&amp;url=http%3A%2F%2",
        "Fwww%2Elightingnewyork%2Ecom%2Fproduct%2Ftriarch%252Dlightin",
        "g%252Dlacosta%252Dflush%252Dmount%252D31406%252D17%2Ehtml%3F",
        "utm%5Fsource%3Dpricegrabber%26utm%5Fmedium%3Dcse&amp;st=feed",
        "&amp;mt=~~~~~~~~n~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=5316&amp;m=78148",
        "6981&amp;q=n&amp;priceret=16.19&amp;pg=~~3&amp;k=af4ac4bab3d",
        "b7c7a6083abb4154aa815&amp;source=feed&amp;url=http%3A%2F%2Fw",
        "ww%2Eamazon%2Ecom%2Fdp%2FB000NJE3W4%2Fref%3Dasc%5Fdf%5FB000N",
        "JE3W41463596%3Fsmid%3DAKZ54EXMVZHXW%26tag%3Dpgmp%2D681%2D01%",
        "2D20%26linkCode%3Dasn%26creative%3D395105%26creativeASIN%3DB",
        "000NJE3W4&amp;st=feed&amp;mt=~~~~~~~~n~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=18054&amp;m=8008",
        "70361&amp;q=n&amp;priceret=82.17&amp;pg=~~2&amp;k=e54f9c91f9",
        "d8f4e30f2faa1fd100f1cb&amp;source=feed&amp;url=http%3A%2F%2F",
        "www%2Efinditparts%2Ecom%2Fproducts%2Ftimken%2Ddrkc725%3Fcpao",
        "%3D114&amp;st=feed&amp;mt=~~~~~~~~y~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=19238&amp;m=8380",
        "44920&amp;q=n&amp;priceret=3913.70&amp;pg=~~3&amp;k=522c6401",
        "f7b9636d0840b768a99d30f3&amp;source=feed&amp;url=http%3A%2F%",
        "2Fwww%2Ewebstores123%2Ecom%2FStore%2FTracker%2Easpx%3FProduc",
        "tID%3D247887%26ProductFeedID%3D19&amp;st=feed&amp;mt=~~~~~~~",
        "~n~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=5316&amp;m=86161",
        "7177&amp;q=n&amp;priceret=28.40&amp;pg=~~3&amp;k=fa57151d4c2",
        "f270230216605fe3cc386&amp;source=feed&amp;url=http%3A%2F%2Fw",
        "ww%2Eamazon%2Ecom%2Fgp%2Foffer%2Dlisting%2FB004Q2N0C8%2Fref%",
        "3Dasc%5Fdf%5FB004Q2N0C81463599%3Fie%3DUTF8%26condition%3Dnew",
        "%26tag%3Dpgmp%2D996%2D01%2D20%26creative%3D395165%26creative",
        "ASIN%3DB004Q2N0C8%26linkCode%3Dasm&amp;st=feed&amp;mt=~~~~~~",
        "~~n~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=3073&amp;i=97815",
        "95551115&amp;q=n&amp;priceret=10.54&amp;pg=~~3&amp;k=49efe40",
        "adac21fcfa765962d6d93bb16&amp;source=feed&amp;url=http%3A%2F",
        "%2Flink%2Emercent%2Ecom%2Fredirect%2Eashx%3Fmr%3AmerchantID%",
        "3DBarnesandNoble%26mr%3AtrackingCode%3D0687A9ED%2D6B81%2DDE1",
        "1%2DB7F3%2D0019B9C043EB%26mr%3AtargetUrl%3Dhttp%3A%2F%2Fsear",
        "ch%2Ebarnesandnoble%2Ecom%2FAmerica%2FWilliam%2DJ%2DBennett%",
        "2Fe%2F9781595551115%253fsourceid%253dH000000004%2526cm%5Fmmc",
        "%253dPriceGrabber%2D%5F%2DCategory%2D%5F%2DTitle%2D%5F%2D978",
        "1595551115&amp;st=feed&amp;mt=~~~~~~~~n~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=4450&amp;m=70923",
        "3191&amp;q=n&amp;priceret=211.99&amp;pg=~~2&amp;k=373f9a0710",
        "58a1da67683a6d72c7df6e&amp;source=feed&amp;url=http%3A%2F%2F",
        "www%2Ecsnlighting%2Ecom%2Fasp%2Fsuperbrowse%2Easp%3Fclid%3D1",
        "79%26caid%3D%26sku%3DMU4641%26refid%3DPG19%2DMU4641&amp;st=f",
        "eed&amp;mt=~~~~~~~~y~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=6096&amp;m=75219",
        "5827&amp;q=n&amp;priceret=13.75&amp;pg=~~3&amp;k=d4a264ac287",
        "8e05d69b1eda19bbf67bb&amp;source=feed&amp;url=http%3A%2F%2Fw",
        "ww%2Etechnologylk%2Ecom%2F1%2D1%2D2%2Dsteel%2Dball%2Dbearing",
        "%2Dsliding%2Dglass%2Ddoor%2Droller%2Dwith%2D3%2D4%2Dwide%2De",
        "xtruded%2Dadjustable%2Dhousing%2Dlk%2DD1912%2Ehtm%3Fsrc%3Dpr",
        "icegraber&amp;st=feed&amp;mt=~~~~~~~~n~~~",
        "http://yahooshopping.pgpartner.com/rd.php?r=3620&amp;m=81346",
        "8695&amp;q=n&amp;priceret=114.95&amp;pg=~~2&amp;k=a188255a6d",
        "6138add3d6c3ec355c5f12&amp;source=feed&amp;url=http%3A%2F%2F",
        "tracking%2Esearchmarketing%2Ecom%2Fclick%2Easp%3Faid%3D43384",
        "1141&amp;st=feed&amp;mt=~~~~~~~~y~~~",
    };

    private static void initDict() {
        int n = 0;
        for (String u : dict_urls) {
            byte[] ub = Utf8.toBytes(u);
            n += ub.length;
        }
        dictionary = new byte[n];
        n = 0;
        for (String u : dict_urls) {
            byte[] ub = Utf8.toBytes(u);
            System.arraycopy(ub, 0, dictionary, n, ub.length);
            n += ub.length;
        }
        assert (n == dictionary.length);
    }

    static {
        initDict();
    }
}
