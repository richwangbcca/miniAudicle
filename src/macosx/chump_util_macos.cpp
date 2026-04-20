/*----------------------------------------------------------------------------
 miniAudicle — macOS-specific implementation of chump/include/util.h

 Replaces chump/src/util.cpp for the miniAudicle build:
   - hash_file()  uses CommonCrypto (no OpenSSL dependency)
   - unzipFile()  uses ditto(1)     (no minizip dependency)
   - TC::* and ck_isatty() are omitted — already in ChucK's util_string.cpp
     and util_platforms.cpp which are compiled into this binary.
 -----------------------------------------------------------------------------*/

#include "util.h"
#include "package_list.h"

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <regex>
#include <sstream>
#include <system_error>

#include <CommonCrypto/CommonDigest.h>
#include <nlohmann/json.hpp>
#include <unistd.h>

using json = nlohmann::json;

fs::path packagePath(Package p, fs::path install_dir)
{
    return install_dir / p.name;
}

fs::path chumpDir()
{
    fs::path home = getHomeDirectory();
    return home / ".chuck" / "packages";
}

std::string manifestURL(std::string base_url)
{
    return base_url + "v" + std::to_string(MANIFEST_VERSION_NO) + "/manifest.json";
}

std::string whichOS()
{
    return "mac";
}

Architecture whichArch()
{
#if defined(__x86_64__) || defined(_M_X64)
    return X86_64;
#elif defined(__aarch64__) || defined(_M_ARM64)
    return ARM64;
#elif defined(i386) || defined(__i386__)
    return X86;
#else
    throw std::system_error(EINVAL, std::generic_category(),
                            "[chump]: unsupported architecture");
#endif
}

fs::path getHomeDirectory()
{
    const char *home = std::getenv("HOME");
    if (!home)
        throw std::runtime_error("Failed to get user's home directory");
    return home;
}

tuple<string, optional<string>> parsePackageName(string packageName)
{
    std::regex pattern("(.*)=(.*)");
    std::smatch matches;
    if (std::regex_match(packageName, matches, pattern))
        return { matches[1], optional<string>(matches[2].str()) };
    return { packageName, {} };
}

bool is_subpath(const fs::path &path, const fs::path &base)
{
    if (path == base) return true;
    auto rel = fs::absolute(path).lexically_relative(fs::absolute(base));
    return !rel.empty() && rel.native()[0] != '.';
}

std::string hash_file(fs::path filename)
{
    std::ifstream file(filename, std::ios::binary);
    if (!file)
        throw std::runtime_error("Failed to open file: " + filename.string());

    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);

    char buf[4096];
    while (file.read(buf, sizeof(buf)) || file.gcount() > 0)
        CC_SHA256_Update(&ctx, buf, (CC_LONG)file.gcount());

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &ctx);

    std::ostringstream ss;
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i)
        ss << std::hex << std::setw(2) << std::setfill('0') << (int)digest[i];
    return ss.str();
}

bool validate_manifest(fs::path manifest_path)
{
    if (!fs::exists(manifest_path)) {
        std::cerr << "[chump]: unable to find package list (manifest.json), fetching..." << std::endl;
        return false;
    }
    try {
        PackageList p(manifest_path);
    } catch (const std::exception &e) {
        std::cerr << "[chump]: failed to validate manifest.json: " << e.what() << std::endl;
        return false;
    }
    return true;
}

fs::path fileTypeToDir(FileType f)
{
    switch (f) {
    case DATA_FILE:    return fs::path("_data");
    case EXAMPLE_FILE: return fs::path("_examples");
    case DOCS_FILE:    return fs::path("_docs");
    case DEPS_FILE:    return fs::path("_deps");
    default:           return fs::path();
    }
}

bool unzipFile(const std::string &zipPath, const std::string &outputDir)
{
    fs::create_directories(outputDir);
    std::string cmd = "ditto -xk " +
                      std::string("\"") + zipPath    + "\" " +
                      std::string("\"") + outputDir  + "\"";
    int rc = std::system(cmd.c_str());
    if (rc != 0) {
        std::cerr << "[chump]: ditto failed to unzip " << zipPath << std::endl;
        return false;
    }
    return true;
}

string to_lower(const string &str)
{
    string s = str;
    std::transform(s.begin(), s.end(), s.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    return s;
}

optional<InstalledVersion> getInstalledVersion(fs::path dir)
{
    if (!fs::is_directory(dir)) {
        std::cerr << "[chump]: path " << dir << " is not a directory" << std::endl;
        return {};
    }

    fs::path json_path = dir / "version.json";
    if (!fs::exists(json_path)) {
        std::cerr << "[chump]: file " << json_path << " not found" << std::endl;
        return {};
    }

    std::ifstream f(json_path);
    if (!f.good()) {
        std::cerr << "[chump]: unable to open " << json_path << std::endl;
        return {};
    }

    InstalledVersion iv;
    try {
        json pkg_ver = json::parse(f);
        f.close();
        iv = pkg_ver.template get<InstalledVersion>();
    } catch (const std::exception &e) {
        f.close();
        std::cerr << "[chump]: exception parsing " << json_path << ": " << e.what() << std::endl;
        return {};
    }

    return iv;
}

