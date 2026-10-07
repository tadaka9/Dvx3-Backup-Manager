/**
 * example.cpp - C++ example using dvx3 library
 * 
 * Demonstrates encryption and decryption with progress tracking.
 */

#include "dvx3.hpp"
#include <iostream>
#include <iomanip>
#include <chrono>
#include <cstring>

using namespace std;
using namespace dvx3;

// Simple progress bar
void print_progress(const string& label, uint64_t processed, uint64_t total, uint64_t output) {
    double pct = total > 0 ? static_cast<double>(processed) / total * 100.0 : 0.0;
    if (pct > 100.0) pct = 100.0;
    
    int bar_width = 30;
    int filled = static_cast<int>(pct / 100.0 * bar_width);
    
    cout << "\r" << label << " [";
    for (int i = 0; i < bar_width; i++) {
        cout << (i < filled ? "=" : " ");
    }
    cout << "] " << fixed << setprecision(1) << pct << "% | "
         << format_size(processed) << " -> " << format_size(output);
    cout.flush();
}

void show_usage(const char* prog) {
    cerr << "Usage:\n";
    cerr << "  " << prog << " encrypt <folder> <output.dvx3> <password>\n";
    cerr << "  " << prog << " decrypt <archive.dvx3> <output_dir> <password>\n";
}

int main(int argc, char** argv) {
    if (argc < 5) {
        show_usage(argv[0]);
        return 1;
    }

    string mode = argv[1];
    string input = argv[2];
    string output = argv[3];
    string password = argv[4];

    try {
        auto start = chrono::steady_clock::now();

        if (mode == "encrypt") {
            cout << "Encrypting: " << input << " -> " << output << "\n";
            
            encrypt(input, output, password, "", 
                [](uint64_t proc, uint64_t tot, uint64_t out) {
                    print_progress("Encrypt", proc, tot, out);
                });
            
            cout << "\n✅ Encryption complete!\n";

        } else if (mode == "decrypt") {
            cout << "Decrypting: " << input << " -> " << output << "\n";
            
            decrypt(input, output, password,
                [](uint64_t proc, uint64_t tot, uint64_t out) {
                    print_progress("Decrypt", proc, tot, out);
                });
            
            cout << "\n✅ Decryption complete!\n";

        } else {
            cerr << "Unknown mode: " << mode << "\n";
            show_usage(argv[0]);
            return 1;
        }

        auto end = chrono::steady_clock::now();
        auto duration = chrono::duration_cast<chrono::milliseconds>(end - start);
        cout << "Time: " << duration.count() / 1000.0 << "s\n";

    } catch (const Exception& e) {
        cerr << "❌ Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
