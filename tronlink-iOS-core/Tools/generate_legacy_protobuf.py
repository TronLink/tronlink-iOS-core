#!/usr/bin/env python3
"""Regenerate the four legacy Objective-C protobuf models with protoc 29.3."""

import os
from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
PROTOC = os.environ.get("TLCORE_PROTOC", "protoc")
SOURCES = ("descriptor.proto", "http.proto", "annotations.proto", "api/zksnark.proto")
OUTPUTS = {
    "Descriptor": "google/protobuf/Descriptor",
    "HTTP": "google/api/HTTP",
    "Annotations": "google/api/Annotations",
    "api/Zksnark": "api/Zksnark",
}

# protoc now escapes `weak`. Keep the original public accessors while using the
# generator's field metadata and implementations unchanged.
LEGACY_HEADER = """
// TLCore compatibility: names exposed before protoc escaped `weak` as `weak_p`.
@interface GPBFieldOptions (TLCoreLegacyFieldNames)
@property(nonatomic, readwrite) BOOL weak;
@property(nonatomic, readwrite) BOOL hasWeak;
@end
"""
LEGACY_IMPLEMENTATION = """
// TLCore compatibility: delegate to the generated field and presence accessors.
@implementation GPBFieldOptions (TLCoreLegacyFieldNames)
- (BOOL)weak { return self.weak_p; }
- (void)setWeak:(BOOL)value { self.weak_p = value; }
- (BOOL)hasWeak { return self.hasWeak_p; }
- (void)setHasWeak:(BOOL)value { self.hasWeak_p = value; }
@end
"""


def main():
    version = subprocess.check_output([PROTOC, "--version"], text=True).strip()
    if version != "libprotoc 29.3":
        raise SystemExit(f"Expected libprotoc 29.3, found {version}; set TLCORE_PROTOC.")

    with tempfile.TemporaryDirectory(prefix="tlcore-protobuf-") as directory:
        subprocess.run(
            [PROTOC, f"--proto_path={ROOT / 'Protos/legacy'}",
             f"--objc_out={directory}", *SOURCES],
            check=True,
        )
        for generated, target in OUTPUTS.items():
            for suffix in (".pbobjc.h", ".pbobjc.m"):
                content = (Path(directory) / (generated + suffix)).read_text()
                if generated == "api/Zksnark":
                    # TLCore already names protocol.Transaction's ObjC class
                    # TronTransaction. Do not rename the protocol message itself.
                    content = re.sub(r"\bTransaction\b", "TronTransaction", content)
                    content = content.replace('"api/Zksnark.pbobjc.h"', '"Zksnark.pbobjc.h"')
                    content = content.replace('"core/Tron.pbobjc.h"', '"Tron.pbobjc.h"')
                if generated == "Descriptor":
                    if suffix == ".pbobjc.h":
                        content = content.replace(
                            "  GPBFieldOptions_FieldNumber_Weak_p = 10,",
                            "  GPBFieldOptions_FieldNumber_Weak_p = 10,\n"
                            "  GPBFieldOptions_FieldNumber_Weak = GPBFieldOptions_FieldNumber_Weak_p,",
                        )
                        content += LEGACY_HEADER
                    else:
                        content += LEGACY_IMPLEMENTATION
                destination = ROOT / "Classes/gRPC" / (target + suffix)
                destination.write_text(content)
                print(destination.relative_to(ROOT))


if __name__ == "__main__":
    main()
