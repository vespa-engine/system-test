#!/usr/bin/env python3
"""Compare JSON and CBOR responses to ensure they're identical after deserialization."""

import json
import sys
import cbor2

def compare_responses(json_file, cbor_file):
    """Compare JSON and CBOR responses."""
    # Load JSON
    with open(json_file, 'r') as f:
        json_data = json.load(f)

    # Load CBOR
    with open(cbor_file, 'rb') as f:
        cbor_data = cbor2.load(f)

    # Compare
    if json_data == cbor_data:
        print("✓ JSON and CBOR responses are identical")
        return 0
    else:
        print("✗ JSON and CBOR responses differ!")
        print(f"\nJSON keys: {set(json_data.keys()) if isinstance(json_data, dict) else 'not a dict'}")
        print(f"CBOR keys: {set(cbor_data.keys()) if isinstance(cbor_data, dict) else 'not a dict'}")

        # Show differences
        if isinstance(json_data, dict) and isinstance(cbor_data, dict):
            for key in set(json_data.keys()) | set(cbor_data.keys()):
                if json_data.get(key) != cbor_data.get(key):
                    print(f"\nDifference in key '{key}':")
                    print(f"  JSON: {json_data.get(key)}")
                    print(f"  CBOR: {cbor_data.get(key)}")
        return 1

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: compare_responses.py <json_file> <cbor_file>")
        sys.exit(1)

    sys.exit(compare_responses(sys.argv[1], sys.argv[2]))
