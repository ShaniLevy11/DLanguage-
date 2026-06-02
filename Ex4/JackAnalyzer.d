module Ex4.JackAnalyzer;

import std.stdio;
import std.file;
import std.path;
import std.array;
import std.algorithm;
import Ex4.JackTokenizer;
import Ex4.CompilationEngine;

void processFile(string inputPath) {
    string outputPath = stripExtension(inputPath) ~ ".My.xml"; 
    
    auto tokenizer = new JackTokenizer(inputPath);
    
    if (tokenizer.hasMoreTokens()) {
        tokenizer.advance();
    }
    
    auto engine = new CompilationEngine(tokenizer, outputPath);
    engine.compileClass(); 
    
    writefln("Success! Parsed structure created: %s", outputPath);
}

int main(string[] args) {
    if (args.length < 2) {
        writeln("Usage: JackAnalyzer <path_to_file_or_directory>");
        return 1;
    }

    string inputPath = args[1];

    if (!exists(inputPath)) {
        writeln("Error: Path not found.");
        return 1;
    }

    auto files = appender!(string[]);

    if (isDir(inputPath)) {
        foreach (DirEntry entry; dirEntries(inputPath, SpanMode.shallow)) {
            if (entry.isFile && entry.name.endsWith(".jack")) {
                files.put(entry.name);
            }
        }
    } else if (inputPath.endsWith(".jack")) {
        files.put(inputPath);
    }

    if (files.data.length == 0) {
        writeln("No .jack files found to process.");
        return 0;
    }

    foreach (file; files.data) {
        processFile(file);
    }

    return 0;
}