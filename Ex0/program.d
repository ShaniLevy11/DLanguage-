module Tar0.program;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.conv;
import std.algorithm;
import std.format;
import std.array;

File outFile;
double totalBuys = 0.0;
double totalSells = 0.0;

void HandleBuy(string productName, int amount, double price) {
    double lineValue = amount * price;
    string line1 = format("### BUY %s ###", productName);
    string line2 = format("%g", lineValue);
    
    outFile.writeln(line1);
    outFile.writeln(line2);
    writeln(line1);
    writeln(line2);
    
    totalBuys += lineValue;
}

void HandleSell(string productName, int amount, double price) {
    double lineValue = amount * price;
    string line1 = format("$$$ CELL %s $$$", productName);
    string line2 = format("%g", lineValue);
    
    outFile.writeln(line1);
    outFile.writeln(line2);
    writeln(line1);
    writeln(line2);
    
    totalSells += lineValue;
}

void main(string[] args) {
    if (args.length < 2) {
        writeln("Usage: hello.exe <directory_path>");
        return;
    }

    string folderPath = args[1];
    string resolvedFolderPath = absolutePath(folderPath);

    // baseName can be "." or empty for relative/special forms, so normalize first.
    string folderName = baseName(resolvedFolderPath);
    if (folderName.length == 0 || folderName == ".") {
        folderName = baseName(dirName(resolvedFolderPath));
    }

    string outputPath = buildPath(resolvedFolderPath, folderName ~ ".asm");

    outFile = File(outputPath, "w");

    auto entries = dirEntries(resolvedFolderPath, SpanMode.shallow)
        .filter!(e => e.isFile && toLower(extension(e.name)) == ".vm")
        .array;
    
    // Sort by name to ensure deterministic order (e.g. InputA before InputB)
    sort!("a.name < b.name")(entries);

    foreach (entry; entries) {
        string vmFileName = stripExtension(baseName(entry.name));
        outFile.writeln(vmFileName);
        writeln(vmFileName);

        auto inFile = File(entry.name, "r");
        foreach (line; inFile.byLineCopy()) {
            auto words = line.strip().split();
            string command = words[0];
            string productName = words[1];
            int amount = to!int(words[2]);
            double price = to!double(words[3]);

            if (command == "buy") {
                HandleBuy(productName, amount, price);
            } else if (command == "sell" || command == "cell") {
                HandleSell(productName, amount, price);
            }
        }
    }

    string buysLine = format("TOTAL BUY: %g", totalBuys);
    string sellsLine = format("TOTAL CELL: %g", totalSells);

    writeln(buysLine);
    writeln(sellsLine);

    outFile.writeln(buysLine);
    outFile.writeln(sellsLine);
}