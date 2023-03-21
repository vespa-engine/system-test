// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <cstdlib>
#include <cstdio>
#include <cstdint>
#include <sstream>
#include <vector>
#include <cassert>

namespace {

const char base64Chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                           "abcdefghijklmnopqrstuvwxyz"
                           "0123456789+/=";

int
getMaximumEncodeLength(int sourcelen) {
    return std::max(6, 2 * sourcelen + 2);
}

int
encode(const char *inBuffer, int inLen, char *outBuffer, int outBufLen)
{
    int i;
    int outLen = 0;
    for (i = 0; inLen >= 3; inLen -= 3) {
        if (outBufLen - outLen < 4) {
            return -1;
        }
        // Do this to keep chars > 127
        unsigned char a = inBuffer[i];
        unsigned char b = inBuffer[i+1];
        unsigned char c = inBuffer[i+2];
        i += 3;

        outBuffer[outLen    ] = base64Chars[ a >> 2 ];
        outBuffer[outLen + 1] = base64Chars[ (a << 4 & 0x30) | (b >> 4) ];
        outBuffer[outLen + 2] = base64Chars[ (b << 2 & 0x3c) | (c >> 6) ];
        outBuffer[outLen + 3] = base64Chars[ c & 0x3f  ];

        outLen += 4;
    }

    if (inLen) {
        if (outBufLen - outLen < 4) {
            return -1;
        }
        // Do this to keep chars with value>127
        unsigned char a = inBuffer[i];

        outBuffer[outLen] = base64Chars[ a >> 2 ];

        if (inLen == 1) {
            outBuffer[outLen + 1] = base64Chars[ (a << 4 & 0x30) ];
            outBuffer[outLen + 2] = '=';
        } else {
            unsigned char b = inBuffer[i + 1];
            outBuffer[outLen + 1] = base64Chars[ (a << 4 & 0x30) | (b >> 4) ];
            outBuffer[outLen + 2] = base64Chars[ b << 2 & 0x3c ];
        }

        outBuffer[outLen + 3] = '=';

        outLen += 4;
    }

    if (outLen >= outBufLen)
        return -1;

    outBuffer[outLen] = '\0';

    return outLen;
}


std::string
encode(const char* source, int len)
{
    // Assign a string that we know is long enough
    std::string result(getMaximumEncodeLength(len), '\0');
    int outlen = encode(source, len, &result[0], result.size());
    assert(outlen >= 0); // Make sure buffer was big enough.
    result.resize(outlen);
    return result;
}

}

std::string
create_keys(unsigned long offset, unsigned long numKeys) {
    std::stringstream os;
    os << '"' << offset << "\":" << 1;
    for (unsigned long i(1); i < numKeys; i++) {
      os << ",\"" << (offset + i) << "\":" << 1;
    }
    return os.str();
}

template<typename T>
std::string
create_values(unsigned long numValues) {
    std::stringstream os;
    os << long(T(random()));
    for (unsigned long i(1); i < numValues; i++) {
      os << ',' << long(T(random()));
    }
    return os.str();
}

std::string
create_raw(unsigned long numValues) {
    std::vector<char> bytes;
    bytes.reserve(numValues);
    for (unsigned long i(0); i < numValues; i++) {
        bytes.push_back(random());
    }
    return encode(bytes.data(), bytes.size());
}

void
doc(unsigned long num, unsigned long numKeys, unsigned long numBytes) {
    std::string keys = create_keys(num * numKeys, numKeys);
    std::string bytes = create_values<int8_t>(numBytes);
    std::string longs = create_values<int64_t>((numBytes + (sizeof(long) - 1))/sizeof(long));
    std::string raw = create_raw(numBytes);

    printf("{\"id\":\"id:test:test::%d\", \"fields\":{"
           "    \"id\":%lu,"
           "    \"f1\":{%s},"
           "    \"s1\":{%s},"
           "    \"payload_raw\":\"%s\","
           "    \"payload_array_byte\":[%s],"
           "    \"payload_array_long\":[%s]"
           " } }",
           num, num, keys.c_str(), keys.c_str(), raw.c_str(), bytes.c_str(), longs.c_str());
}

int
main(int argc, char **argv) {
    int i;
    int numDocs = atoi(argv[1]);
    int numKeys = atoi(argv[2]);
    int numBytes = atoi(argv[3]);
    printf("[\n");
    for (i = 0; i < (numDocs-1); i++) {
        doc(i, numKeys, numBytes);
        printf(",\n");
    }
    doc(i, numKeys, numBytes);
    printf("\n]\n");
    return 0;
}
