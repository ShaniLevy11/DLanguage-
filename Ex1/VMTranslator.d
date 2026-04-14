import std.stdio;
import std.file;
import std.string;
import std.path;
import std.conv;
import std.array;

// Global variables
int labelCounter = 0;
string inputFile = "";
string outputFile = "";

// Append text to output file
void writeText(string text) {
    append(outputFile, text);
}

// Get file name without extension
string getFileTitle(string path) {
    return baseName(stripExtension(path));
}

// Translate push constant x
string translatePushConstant(string value) {
    string result = "@" ~ value ~ "\n";
    result ~= "D=A\n";
    result ~= "@SP\n";
    result ~= "A=M\n";
    result ~= "M=D\n";
    result ~= "@SP\n";
    result ~= "M=M+1\n";
    return result;
}

// Translate add command
string translateAdd() {
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "M=M+D\n";
    return result;
}

// Translate sub command
string translateSub() {
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "M=M-D\n";
    return result;
}

// Translate neg command
string translateNeg() {
    string result = "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=-M\n";
    return result;
}

// Translate and command
string translateAnd() {
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "M=M&D\n";
    return result;
}

// Translate or command
string translateOr() {
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "M=M|D\n";
    return result;
}

// Translate not command
string translateNot() {
    string result = "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=!M\n";
    return result;
}

// Translate eq command
string translateEq() {
    string trueLabel = "TRUE" ~ to!string(labelCounter);
    string endLabel = "END" ~ to!string(labelCounter);
    labelCounter++;

    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "D=M-D\n";
    result ~= "@" ~ trueLabel ~ "\n";
    result ~= "D;JEQ\n";
    result ~= "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=0\n";
    result ~= "@" ~ endLabel ~ "\n";
    result ~= "0;JMP\n";
    result ~= "(" ~ trueLabel ~ ")\n";
    result ~= "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=-1\n";
    result ~= "(" ~ endLabel ~ ")\n";
    return result;
}

// Translate gt command
string translateGt() {
    string trueLabel = "TRUE" ~ to!string(labelCounter);
    string endLabel = "END" ~ to!string(labelCounter);
    labelCounter++;

    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "D=M-D\n";
    result ~= "@" ~ trueLabel ~ "\n";
    result ~= "D;JGT\n";
    result ~= "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=0\n";
    result ~= "@" ~ endLabel ~ "\n";
    result ~= "0;JMP\n";
    result ~= "(" ~ trueLabel ~ ")\n";
    result ~= "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=-1\n";
    result ~= "(" ~ endLabel ~ ")\n";
    return result;
}

// Translate lt command
string translateLt() {
    string trueLabel = "TRUE" ~ to!string(labelCounter);
    string endLabel = "END" ~ to!string(labelCounter);
    labelCounter++;

    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "D=M-D\n";
    result ~= "@" ~ trueLabel ~ "\n";
    result ~= "D;JLT\n";
    result ~= "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=0\n";
    result ~= "@" ~ endLabel ~ "\n";
    result ~= "0;JMP\n";
    result ~= "(" ~ trueLabel ~ ")\n";
    result ~= "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=-1\n";
    result ~= "(" ~ endLabel ~ ")\n";
    return result;
}

// Map segment to base symbol
string segmentBase(string segment) {
    if (segment == "local") return "LCL";
    if (segment == "argument") return "ARG";
    if (segment == "this") return "THIS";
    if (segment == "that") return "THAT";
    return "";
}

// Translate push segment i
string translatePushSegment(string segment, string index) {
    string base = segmentBase(segment);
    string result = "@" ~ base ~ "\n";
    result ~= "D=M\n";
    result ~= "@" ~ index ~ "\n";
    result ~= "A=D+A\n";
    result ~= "D=M\n";
    result ~= "@SP\n";
    result ~= "A=M\n";
    result ~= "M=D\n";
    result ~= "@SP\n";
    result ~= "M=M+1\n";
    return result;
}

// Translate pop segment i
string translatePopSegment(string segment, string index) {
    string base = segmentBase(segment);
    string result = "@" ~ base ~ "\n";
    result ~= "D=M\n";
    result ~= "@" ~ index ~ "\n";
    result ~= "D=D+A\n";
    result ~= "@R13\n";
    result ~= "M=D\n";
    result ~= "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@R13\n";
    result ~= "A=M\n";
    result ~= "M=D\n";
    return result;
}

// Push temp
string translatePushTemp(string indexStr) {
    int index = to!int(indexStr);
    int addr = 5 + index;
    string result = "@" ~ to!string(addr) ~ "\n";
    result ~= "D=M\n";
    result ~= "@SP\n";
    result ~= "A=M\n";
    result ~= "M=D\n";
    result ~= "@SP\n";
    result ~= "M=M+1\n";
    return result;
}

// Pop temp
string translatePopTemp(string indexStr) {
    int index = to!int(indexStr);
    int addr = 5 + index;
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@" ~ to!string(addr) ~ "\n";
    result ~= "M=D\n";
    return result;
}

// Pointer name
string pointerName(string index) {
    if (index == "0") return "THIS";
    return "THAT";
}

// Push pointer
string translatePushPointer(string index) {
    string base = pointerName(index);
    string result = "@" ~ base ~ "\n";
    result ~= "D=M\n";
    result ~= "@SP\n";
    result ~= "A=M\n";
    result ~= "M=D\n";
    result ~= "@SP\n";
    result ~= "M=M+1\n";
    return result;
}

// Pop pointer
string translatePopPointer(string index) {
    string base = pointerName(index);
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@" ~ base ~ "\n";
    result ~= "M=D\n";
    return result;
}

// Push static
string translatePushStatic(string index) {
    string name = getFileTitle(inputFile) ~ "." ~ index;
    string result = "@" ~ name ~ "\n";
    result ~= "D=M\n";
    result ~= "@SP\n";
    result ~= "A=M\n";
    result ~= "M=D\n";
    result ~= "@SP\n";
    result ~= "M=M+1\n";
    return result;
}

// Pop static
string translatePopStatic(string index) {
    string name = getFileTitle(inputFile) ~ "." ~ index;
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@" ~ name ~ "\n";
    result ~= "M=D\n";
    return result;
}

// Process one line
string processLine(string line) {
    string clean = line.replace("\r", "");
    
    // Remove inline comments
    ptrdiff_t commentPos = clean.indexOf("//");
    if (commentPos != -1) {
        clean = clean[0 .. commentPos];
    }
    clean = clean.strip();

    // Skip empty line
    if (clean.length == 0) return "";

    string[] words = clean.split();
    string command = words[0];

    // push
    if (command == "push") {
        string segment = words[1];
        string value = words[2];

        if (segment == "constant") return translatePushConstant(value);
        else if (segment == "local" || segment == "argument" || segment == "this" || segment == "that") 
            return translatePushSegment(segment, value);
        else if (segment == "temp") return translatePushTemp(value);
        else if (segment == "pointer") return translatePushPointer(value);
        else if (segment == "static") return translatePushStatic(value);
    }
    // pop
    else if (command == "pop") {
        string segment = words[1];
        string value = words[2];

        if (segment == "local" || segment == "argument" || segment == "this" || segment == "that")
            return translatePopSegment(segment, value);
        else if (segment == "temp") return translatePopTemp(value);
        else if (segment == "pointer") return translatePopPointer(value);
        else if (segment == "static") return translatePopStatic(value);
    }
    // arithmetic
    else if (command == "add") return translateAdd();
    else if (command == "sub") return translateSub();
    else if (command == "neg") return translateNeg();
    else if (command == "and") return translateAnd();
    else if (command == "or") return translateOr();
    else if (command == "not") return translateNot();
    else if (command == "eq") return translateEq();
    else if (command == "gt") return translateGt();
    else if (command == "lt") return translateLt();

    return "";
}

// Process one vm file
void processFile(string filename) {
    string content = readText(filename);
    string[] lines = content.splitLines();

    foreach (line; lines) {
        string asmCode = processLine(line); // שינינו את שם המשתנה מ-asm ל-asmCode
        if (asmCode.length > 0) {
            writeText(asmCode ~ "\n"); // עדכנו גם כאן
        }
    }
}

// Main program
void main(string[] args) {
    if (args.length < 2) {
        writeln("Usage: vm_translator <file.vm>");
        return;
    }

    inputFile = args[1];
    outputFile = stripExtension(inputFile) ~ ".asm";
    labelCounter = 0;

    // Clear or create the output file
    std.file.write(outputFile, "");

    processFile(inputFile);
}