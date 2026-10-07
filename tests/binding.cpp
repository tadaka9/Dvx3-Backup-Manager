// This test verifies the generated C ABI and the C++ RAII wrapper only.
#include "dvx3.hpp"
#include <filesystem>
#include <fstream>
#include <iostream>
int main() {
    namespace fs = std::filesystem;
    GError* error = nullptr;
    gchar* temporary = g_dir_make_tmp("dvx3-binding-XXXXXX", &error);
    if (!temporary) { std::cerr << error->message; g_error_free(error); return 1; }
    const fs::path root(temporary);
    g_free(temporary);
    int status = 0;
    try {
        fs::create_directory(root / "source");
        std::ofstream(root / "source" / "data") << "C++ ABI round trip";
        dvx3::encrypt((root / "source").string(), (root / "archive.dvx3").string(), "binding password");
        dvx3::decrypt((root / "archive.dvx3").string(), (root / "restore").string(), "binding password");
        std::ifstream input(root / "restore" / "data");
        std::string content((std::istreambuf_iterator<char>(input)), {});
        if (content != "C++ ABI round trip") throw std::runtime_error("Restored bytes differ");
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; status = 1; }
    fs::remove_all(root);
    return status;
}
