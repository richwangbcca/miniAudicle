// Stub for chump/src/fetch.cpp which includes <openssl/sha.h> but never calls
// any of its symbols. The actual SHA-256 implementation uses CommonCrypto in
// chump_util_macos.cpp.
#pragma once
