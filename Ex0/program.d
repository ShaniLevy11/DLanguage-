module Tar0.program;

 //shani grunberger- 211835970
 //yael cohen- 326055688
 // group number:150060.21.5786.42


// Standard D library imports
import std.stdio;       // Input/Output operations (writeln, File)
import std.file;        // File system operations (dirEntries, isFile)
import std.path;        // Path manipulation (absolutePath, baseName, buildPath)
import std.string;      // String operations (strip, split, format)
import std.conv;        // Data conversion (to!int, to!double)
import std.algorithm;   // Algorithms (filter, sort)
import std.format;      // String formatting
import std.array;       // Array operations

// Global variables to store program state
File outFile;           // The output file handle
double totalBuys = 0.0; // Accumulator for total buy transactions
double totalSells = 0.0;// Accumulator for total sell transactions

// Handles a 'buy' command: calculates cost, logs it, and updates total
void HandleBuy(string productName, int amount, double price) {
    // Calculate total value for this line
    double lineValue = amount * price;
    
    // Format the output strings
    string line1 = format("### BUY %s ###", productName);
    string line2 = format("%g", lineValue);
    
    // Write to the output file
    outFile.writeln(line1);
    outFile.writeln(line2);
    
    
    
    // Update the global total
    totalBuys += lineValue;
}

// Handles a 'sell' command: calculates revenue, logs it, and updates total
void HandleSell(string productName, int amount, double price) {
    double lineValue = amount * price;
    string line1 = format("$$$ CELL %s $$$", productName);
    string line2 = format("%g", lineValue);
    
    outFile.writeln(line1);
    outFile.writeln(line2);
    
    
    totalSells += lineValue;
}

void main(string[] args) {
    // Check if user provided the input directory argument
    if (args.length < 2) {
        writeln("Usage: hello.exe <directory_path>");
        return;
    }

    // Get the input folder path from arguments
    string folderPath = args[1];
    string resolvedFolderPath = absolutePath(folderPath); // Convert to full path

    // Determine the output file name based on the folder name
    string folderName = baseName(resolvedFolderPath);
    
    // Handle edge case where path might end in a separator or be "."
    if (folderName.length == 0 || folderName == ".") {
        folderName = baseName(dirName(resolvedFolderPath));
    }

    // Output file will be named <FolderName>.asm inside the folder
    string outputPath = buildPath(resolvedFolderPath, folderName ~ ".asm");

    // Open the output file for writing ("w")
    outFile = File(outputPath, "w");

    // Find all files in the directory that end with ".vm"
    auto entries = dirEntries(resolvedFolderPath, SpanMode.shallow)
        .filter!(e => e.isFile && toLower(extension(e.name)) == ".vm")
        .array; // Convert to array for sorting
    
    // Sort files alphabetically by name to ensure consistent processing order
    sort!("a.name < b.name")(entries);

    // Process each .vm file sequentially
    foreach (entry; entries) {
        // Get the filename without extension (e.g. "InputA" from "InputA.vm")
        string vmFileName = stripExtension(baseName(entry.name));
        
        // Write the filename header to output file and console
        outFile.writeln(vmFileName);
        

        // Open the current input file for reading
        auto inFile = File(entry.name, "r");
        
        // Read file line by line
        foreach (line; inFile.byLineCopy()) {
            // Split line into words, removing surrounding whitespace
            auto words = line.strip().split();
            
            // Skip empty lines if any
            if (words.length == 0) continue;

            // Parse the command and arguments
            // Format: <command> <product> <amount> <price>
            string command = words[0];
            string productName = words[1];
            int amount = to!int(words[2]);       // Convert string to integer
            double price = to!double(words[3]);  // Convert string to double

            // Execute the appropriate action based on the command
            if (command == "buy") {
                HandleBuy(productName, amount, price);
            } else if (command == "sell" || command == "cell") {
                // "cell" is treated as an alias for "sell"
                HandleSell(productName, amount, price);
            }
        }
    }

    // Create summary lines for total buys and sells
    string buysLine = format("TOTAL BUY: %g", totalBuys);
    string sellsLine = format("TOTAL CELL: %g", totalSells);

    // Print summary to console
    writeln(buysLine);
    writeln(sellsLine);

    // Print summary to output file
    outFile.writeln(buysLine);
    outFile.writeln(sellsLine);
}