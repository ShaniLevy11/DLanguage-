module VMTranslator;

import std.stdio;
import std.file;
import std.string;
import std.path;
import std.conv;
import std.array;

// ---------------------- GLOBAL STATE ----------------------

// Counter used to generate unique labels for comparison operations (eq, gt, lt)
int labelCounter = 0;

// Input VM file name
string inputFile = "";

// Output ASM file name
string outputFile = "";

// ---------------------- OUTPUT HANDLING ----------------------

// Append generated assembly code to output file
void writeText(string text) {
    append(outputFile, text);
}

// Extract file name without path and extension
string getFileTitle(string path) {
    return baseName(stripExtension(path));
}

// ---------------------- STACK ARITHMETIC ----------------------

string translateInc2() {
    string result = "@SP\n";      // Load the stack pointer (SP) address
    result ~= "A=M-1\n";          // Set A to point to the top element of the stack
    result ~= "M=M+1\n";          // Increment the top stack value by 1

    result ~= "A=A-1\n";          // Move A to the second element from the top
    result ~= "M=M+1\n";          // Increment the second stack value by 1

    return result;                // Return the generated assembly code
}

// push constant x
// Pushes a constant value into the stack
string translatePushConstant(string value) {
    string result = "@" ~ value ~ "\n"; // load constant
    result ~= "D=A\n";                  // D = constant
    result ~= "@SP\n";                  // go to stack pointer
    result ~= "A=M\n";                  // A = top of stack
    result ~= "M=D\n";                  // push value
    result ~= "@SP\n";
    result ~= "M=M+1\n";                // increment SP
    return result;
}

// add (x + y)
// Pops two values and pushes their sum
string translateAdd() {
    string result = "@SP\n";
    result ~= "AM=M-1\n"; // SP--, point to y
    result ~= "D=M\n";    // D = y
    result ~= "A=A-1\n";  // point to x
    result ~= "M=M+D\n";  // x = x + y
    return result;
}

// sub (x - y)
// Pops two values and pushes x - y
string translateSub() {
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "M=M-D\n";
    return result;
}

// neg (-x)
// Negates the top stack value
string translateNeg() {
    string result = "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=-M\n";
    return result;
}

// and (x & y)
// Bitwise AND between top two stack values
string translateAnd() {
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "M=M&D\n";
    return result;
}

// or (x | y)
// Bitwise OR between top two stack values
string translateOr() {
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "A=A-1\n";
    result ~= "M=M|D\n";
    return result;
}

// not (!x)
// Bitwise NOT of top stack value
string translateNot() {
    string result = "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=!M\n";
    return result;
}

// ---------------------- COMPARISON OPERATIONS ----------------------

// eq (x == y)
// Pushes -1 if equal, else 0
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
    result ~= "M=0\n"; // false

    result ~= "@" ~ endLabel ~ "\n";
    result ~= "0;JMP\n";

    result ~= "(" ~ trueLabel ~ ")\n";
    result ~= "@SP\n";
    result ~= "A=M-1\n";
    result ~= "M=-1\n"; // true

    result ~= "(" ~ endLabel ~ ")\n";
    return result;
}

// gt (x > y)
// Pushes -1 if x > y else 0
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

// lt (x < y)
// Pushes -1 if x < y else 0
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

// ---------------------- MEMORY SEGMENTS ----------------------

// Convert VM segment name to Hack base address
string segmentBase(string segment) {
    if (segment == "local") return "LCL";
    if (segment == "argument") return "ARG";
    if (segment == "this") return "THIS";
    if (segment == "that") return "THAT";
    return "";
}

// push segment i
// Push value from memory segment to stack
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

// pop segment i
// Pop value from stack into memory segment
string translatePopSegment(string segment, string index) {
    string base = segmentBase(segment);

    string result = "@" ~ base ~ "\n";
    result ~= "D=M\n";
    result ~= "@" ~ index ~ "\n";
    result ~= "D=D+A\n";
    result ~= "@R13\n";
    result ~= "M=D\n"; // store target address

    result ~= "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";

    result ~= "@R13\n";
    result ~= "A=M\n";
    result ~= "M=D\n";

    return result;
}

// ---------------------- TEMP / POINTER / STATIC ----------------------

// temp segment (fixed RAM range 5–12)
string translatePushTemp(string indexStr) {
    int addr = 5 + to!int(indexStr);

    string result = "@" ~ to!string(addr) ~ "\n";
    result ~= "D=M\n";

    result ~= "@SP\n";
    result ~= "A=M\n";
    result ~= "M=D\n";
    result ~= "@SP\n";
    result ~= "M=M+1\n";

    return result;
}

string translatePopTemp(string indexStr) {
    int addr = 5 + to!int(indexStr);

    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";

    result ~= "@" ~ to!string(addr) ~ "\n";
    result ~= "M=D\n";

    return result;
}

// pointer segment (THIS / THAT)
string pointerName(string index) {
    if (index == "0") return "THIS";
    return "THAT";
}

// push pointer
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

// pop pointer
string translatePopPointer(string index) {
    string base = pointerName(index);

    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";

    result ~= "@" ~ base ~ "\n";
    result ~= "M=D\n";

    return result;
}

// static segment (file-scoped variables)
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

string translatePopStatic(string index) {
    string name = getFileTitle(inputFile) ~ "." ~ index;

    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";

    result ~= "@" ~ name ~ "\n";
    result ~= "M=D\n";

    return result;
}

// ---------------------- EX2: PROGRAM FLOW ----------------------

// label command
string translateLabel(string label) {
    return "(" ~ label ~ ")\n";
}

// goto command
string translateGoto(string label) {
    string result = "@" ~ label ~ "\n";
    result ~= "0;JMP\n";
    return result;
}

// if-goto command
string translateIfGoto(string label) {
    string result = "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@" ~ label ~ "\n";
    result ~= "D;JNE\n";
    return result;
}

// ---------------------- EX2: FUNCTION CALLING ----------------------

// function command
string translateFunction(string functionName, string nVars) {
    string result = "(" ~ functionName ~ ")\n";
    int n = to!int(nVars);
    for (int i = 0; i < n; i++) {
        result ~= translatePushConstant("0");
    }
    return result;
}

// call command
string translateCall(string functionName, string nArgs) {
    string returnLabel = functionName ~ "$ret." ~ to!string(labelCounter++);

    // push returnAddress
    string result = "@" ~ returnLabel ~ "\n";
    result ~= "D=A\n";
    result ~= "@SP\n";
    result ~= "A=M\n";
    result ~= "M=D\n";
    result ~= "@SP\n";
    result ~= "M=M+1\n";

    // push LCL, ARG, THIS, THAT
    string[] segments = ["LCL", "ARG", "THIS", "THAT"];
    foreach (seg; segments) {
        result ~= "@" ~ seg ~ "\n";
        result ~= "D=M\n";
        result ~= "@SP\n";
        result ~= "A=M\n";
        result ~= "M=D\n";
        result ~= "@SP\n";
        result ~= "M=M+1\n";
    }

    // ARG = SP - nArgs - 5
    result ~= "@SP\n";
    result ~= "D=M\n";
    result ~= "@5\n";
    result ~= "D=D-A\n";
    result ~= "@" ~ nArgs ~ "\n";
    result ~= "D=D-A\n";
    result ~= "@ARG\n";
    result ~= "M=D\n";

    // LCL = SP
    result ~= "@SP\n";
    result ~= "D=M\n";
    result ~= "@LCL\n";
    result ~= "M=D\n";

    // goto functionName
    result ~= translateGoto(functionName);

    // (returnAddress)
    result ~= "(" ~ returnLabel ~ ")\n";

    return result;
}

// return command
string translateReturn() {
    // FRAME = LCL
    string result = "@LCL\n";
    result ~= "D=M\n";
    result ~= "@R13\n"; // R13 (FRAME)
    result ~= "M=D\n";

    // RET = *(FRAME - 5)
    result ~= "@5\n";
    result ~= "A=D-A\n";
    result ~= "D=M\n";
    result ~= "@R14\n"; // R14 (RET)
    result ~= "M=D\n";

    // *ARG = pop()
    result ~= "@SP\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@ARG\n";
    result ~= "A=M\n";
    result ~= "M=D\n";

    // SP = ARG + 1
    result ~= "@ARG\n";
    result ~= "D=M+1\n";
    result ~= "@SP\n";
    result ~= "M=D\n";

    // THAT = *(FRAME - 1)
    result ~= "@R13\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@THAT\n";
    result ~= "M=D\n";

    // THIS = *(FRAME - 2)
    result ~= "@R13\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@THIS\n";
    result ~= "M=D\n";

    // ARG = *(FRAME - 3)
    result ~= "@R13\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@ARG\n";
    result ~= "M=D\n";

    // LCL = *(FRAME - 4)
    result ~= "@R13\n";
    result ~= "AM=M-1\n";
    result ~= "D=M\n";
    result ~= "@LCL\n";
    result ~= "M=D\n";

    // goto RET
    result ~= "@R14\n";
    result ~= "A=M\n";
    result ~= "0;JMP\n";

    return result;
}

// ---------------------- PARSER ----------------------

// Process a single VM line and return ASM code
string processLine(string line) {
    string clean = line.replace("\r", ""); // remove Windows newline char

    // remove comments
    ptrdiff_t commentPos = clean.indexOf("//");
    if (commentPos != -1) {
        clean = clean[0 .. commentPos];
    }

    clean = clean.strip(); // remove spaces

    if (clean.length == 0) return ""; // skip empty lines

    string[] words = clean.split();
    string command = words[0];

    // push command
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

    // pop command
    else if (command == "pop") {
        string segment = words[1];
        string value = words[2];

        if (segment == "local" || segment == "argument" || segment == "this" || segment == "that")
            return translatePopSegment(segment, value);
        else if (segment == "temp") return translatePopTemp(value);
        else if (segment == "pointer") return translatePopPointer(value);
        else if (segment == "static") return translatePopStatic(value);
    }

    // arithmetic commands (Ex1)
    else if (command == "add") return translateAdd();
    else if (command == "sub") return translateSub();
    else if (command == "neg") return translateNeg();
    else if (command == "and") return translateAnd();
    else if (command == "or") return translateOr();
    else if (command == "not") return translateNot();
    else if (command == "inc2") return translateInc2();
    else if (command == "eq") return translateEq();
    else if (command == "gt") return translateGt();
    else if (command == "lt") return translateLt();

    // program flow commands (Ex2)
    else if (command == "label") return translateLabel(words[1]);
    else if (command == "goto") return translateGoto(words[1]);
    else if (command == "if-goto") return translateIfGoto(words[1]);

    // function calling commands (Ex2)
    else if (command == "function") return translateFunction(words[1], words[2]);
    else if (command == "call") return translateCall(words[1], words[2]);
    else if (command == "return") return translateReturn();

    return "";
}



// ---------------------- FILE PROCESSING ----------------------

// Read VM file, process line by line, write ASM output
void processFile(string filename) {
    string content = readText(filename);
    string[] lines = content.splitLines();

    foreach (line; lines) {
        string asmCode = processLine(line);

        if (asmCode.length > 0) {
            writeText(asmCode ~ "\n");
        }
    }
}

// ---------------------- MAIN ----------------------

// Program entry point
void main(string[] args) {
    // check input arguments
    if (args.length < 2) {
        writeln("Usage: vm_translator <file.vm or directory>");
        return;
    }

    string inputPath = args[1];
    labelCounter = 0;

    if (exists(inputPath) && isDir(inputPath)) {
        // Directory input
        outputFile = buildPath(inputPath, baseName(inputPath) ~ ".asm");
        
        // Ensure output directory exists
        mkdirRecurse(dirName(outputFile));
        
        // Clear/create output file and write bootstrap
        std.file.write(outputFile, "");
        // writeBootstrap();

        // Process all .vm files in the directory
        foreach (DirEntry entry; dirEntries(inputPath, "*.vm", SpanMode.shallow)) {
            inputFile = entry.name; // Update global for static variables
            processFile(entry.name);
        }
    } else {
        // Single file input
        inputFile = inputPath;
        outputFile = stripExtension(inputFile) ~ ".asm";

        // Ensure output directory exists
        mkdirRecurse(dirName(outputFile));

        // Clear/create output file
        std.file.write(outputFile, "");
        
        // If it's a single file, we might not need bootstrap unless it's part of a larger project structure
        // For simplicity, we assume single files are for simpler tests (like Ex1)
        processFile(inputFile);
    }
}