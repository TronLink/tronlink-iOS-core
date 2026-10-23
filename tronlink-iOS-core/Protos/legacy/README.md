These protocol sources regenerate four legacy Objective-C model groups in Core:
`Zksnark`, `Annotations`, `HTTP`, and `Descriptor`, comprising eight `.pbobjc.h/.m` files.
The main application uses these files through Core rather than maintaining a separate copy.

Run the following command from the Core repository root:

```sh
python3 tronlink-iOS-core/Tools/generate_legacy_protobuf.py
```

Use `protoc 29.3`. If it is not on PATH, set `TLCORE_PROTOC` to its absolute path.
The script only generates these four groups. It does not install Pods, build or launch
the application, or run tests.

**Why protoc 29.3**

The four legacy groups used Objective-C generated code format version 30002.
protoc 29.3 produces format version 30007, matching the format version of the other
16 groups and meeting Protobuf 5.36.1's minimum supported version of 30007.
This does not set the Protobuf Pod version to 29.3: the generator version,
Objective-C generated code format version, and CocoaPods runtime version use
different numbering schemes.

This upgrade also pins the four gRPC Pods to 1.83.1 and Protobuf to 5.36.1,
sets the minimum iOS version to 15.1 for both Core and Example, and removes the
unused SwiftProtobuf dependency. The generator itself only updates the eight
generated files described here; it does not modify Pod configuration.

**Source provenance and scope**

| File | Source |
| --- | --- |
| `descriptor.proto` | `src/google/protobuf/descriptor.proto` from protocolbuffers/protobuf `v3.5.0`. This older schema matches the existing models and avoids introducing newer descriptor fields. The embedded BSD license notice is retained. |
| `http.proto`, `annotations.proto` | `google/api/` from the local googleapis checkout at commit `ded7ed1e4cce7c165c56a417572cebea9bc1d82c`. The two imports in annotations are flattened to match the current library layout; message fields and extension numbers are unchanged. See `licenses/` for the Apache license. |
| `api/zksnark.proto` | `protocol/src/main/protos/api/zksnark.proto` from the local java-tron checkout at commit `212a4ec8e884a60f312797c4586f3388a21401c7`. Its message fields match the existing Zksnark models. |
| `core/Tron.proto`, `core/Discover.proto`, `core/contract/common.proto` | From the same java-tron commit, included only to resolve Zksnark imports. The script does not generate code for these files or overwrite the current Tron transaction models. See `licenses/` for a copy of the LGPL license from java-tron's protocol directory. |
| `google/protobuf/any.proto` | An include file bundled with the local protoc 29.3 installation, used only to resolve the imports above. The embedded BSD license notice is retained. The runtime-provided GPBAny is not generated or overwritten. |

These source snapshots make generation independent of personal desktop directories
and network access. This directory is outside `Classes` and does not match the
podspec's application source glob.
Do not generate every proto in this directory and overwrite the application models:
the import dependencies have not been established as exact matches for all historical
generated files in the library.

**Project compatibility adjustments after generation**

- Preserve `TronTransaction` as the Objective-C type of `ZksnarkRequest.transaction`.
  The script maps class references in the generated code without renaming
  `protocol.Transaction` in the `.proto` schema.
- Preserve the current flattened CocoaPods header import paths.
- The newer generator uses `GPBFieldOptions.weak_p` / `hasWeak_p`. A forwarding
  category preserves the legacy `weak` / `hasWeak` properties, and the
  `GPBFieldOptions_FieldNumber_Weak` enum alias is retained. Generated field
  metadata is unchanged.
- Leave the existing `Api.pbrpc.h/.m` service wrappers and the other 16 model
  groups untouched.

These adjustments are implemented in the script so they can be reproduced instead
of relying on manual edits to generated output. Standard generator output adds
markers such as `GPB_FINAL`; the source review for this upgrade found no application
code subclassing the message classes in these four groups.

**Regression validation**

Example's `ProtobufUpgradeTests` cover fixed transfer raw_data bytes and txID,
Zksnark wire-format fixtures and transaction types, HTTP oneof and nested messages,
legacy Descriptor properties and field presence, and the HTTP annotation extension
number and registry. Existing transaction signing tests continue to cover the use
of serialized data in signing and public key recovery.

`GRPCCompressionUpgradeTests` are optional local loopback integration tests.
First, run:

```sh
python3 tronlink-iOS-core/Tools/grpc_compression_fixture.py
```

Then set `TLCORE_GRPC_COMPRESSION_FIXTURE=1` in the XCTest process environment
and run the test class. The fixture binds only to `127.0.0.1:19091` and
`127.0.0.1:19092`. The former returns a valid gzip-compressed empty Account;
the latter returns a response smaller than 64 KiB when compressed and 4 MiB
when decompressed.
The tests require the valid response to succeed and the oversized response to
return RESOURCE_EXHAUSTED with an error description containing
`Decompressed message larger than max`. This distinguishes decompression with
an output limit from a size check performed after full decompression.
The tests are skipped unless the environment variable is enabled.
They do not connect to real nodes or sign or broadcast on-chain transactions.

The oversized-response test checks externally observable behavior. Establishing
that allocations are bounded during decompression also requires reviewing
`compression_filter.cc` and `message_compress.cc` in the installed gRPC version.
An error-code assertion is not a measurement of peak memory usage.
