module Ex4.JackTokenizer;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.ascii;
import std.algorithm;
import std.array;
import std.format;

/**
 * TokenType defines the valid token types in the Jack language.
 * Used to identify the essence of the token during the lexical analysis phase.
 */
enum TokenType {
    KEYWORD,
    SYMBOL,
    IDENTIFIER,
    INT_CONST,
    STRING_CONST
}

/**
 * Struct representing a single token with its type and value.
 */
struct Token {
    TokenType type;
    string value;
}

/**
 * Manual comment removal function for source code.
 * This process removes single-line comments (//) and block comments (/* ... *\/),
 * while preserving content inside strings to avoid accidental corruption.
 */
private string stripComments(string input) {
    auto output = appender!string;
    bool inLineComment = false;
    bool inBlockComment = false;
    bool inString = false;

    for (size_t i = 0; i < input.length; i++) {
        char ch = input[i];
        char next = (i + 1 < input.length) ? input[i + 1] : '\0';

        if (ch == '\r') {
            continue;
        }

        if (inLineComment) {
            if (ch == '\n') {
                inLineComment = false;
                output.put(ch);
            }
            continue;
        }

        if (inBlockComment) {
            if (ch == '*' && next == '/') {
                inBlockComment = false;
                i++;
            } else if (ch == '\n') {
                output.put(ch);
            }
            continue;
        }

        if (!inString && ch == '/' && next == '/') {
            inLineComment = true;
            i++;
            continue;
        }

        if (!inString && ch == '/' && next == '*') {
            inBlockComment = true;
            i++;
            continue;
        }

        if (ch == '"') {
            inString = !inString;
            output.put(ch);
            continue;
        }

        output.put(ch);
    }

    return output.data.idup;
}

/**
 * The JackTokenizer class is responsible for breaking down the source code into individual tokens.
 */
class JackTokenizer {
    private string source;
    private size_t index = 0;
    private Token current;

    // List of all keywords permitted in the Jack language
    private static const string[] keywordList = [
        "class", "constructor", "function", "method", "field",
        "static", "var", "int", "char", "boolean", "void",
        "true", "false", "null", "this", "let", "do",
        "if", "else", "while", "return"
    ];

    // List of all symbols permitted in the Jack language
    private static const char[] symbolList = [
        '{', '}', '(', ')', '[', ']', '.', ',', ';',
        '+', '-', '*', '/', '&', '|', '<', '>', '=', '~'
    ];

    /**
     * Class constructor: reads text from the file and strips comments.
     */
    this(string inputFilePath) {
        string rawText = readText(inputFilePath);
        this.source = stripComments(rawText);
    }

    /**
     * Checks if there are more tokens left in the file to process.
     */
    public bool hasMoreTokens() {
        skipSpaces();
        return index < source.length;
    }

    /**
     * Advances the tokenizer to the next token in the input and sets its type and value.
     */
    public void advance() {
        while (true) {
            if (!hasMoreTokens()) {
                return;
            }

            char ch = source[index];

            if (canFind(symbolList, ch)) {
                current = Token(TokenType.SYMBOL, [ch].idup);
                index++;
                return;
            }

            if (ch == '"') {
                index++; // Skip opening quote
                size_t start = index;
                while (index < source.length && source[index] != '"') {
                    index++;
                }
                string val = source[start .. index];
                if (index < source.length) {
                    index++; // Skip closing quote
                }
                current = Token(TokenType.STRING_CONST, val);
                return;
            }

            if (isDigit(ch)) {
                string num = readWhile((char c) => isDigit(c));
                current = Token(TokenType.INT_CONST, num);
                return;
            }

            if (isAlpha(ch) || ch == '_') {
                string word = readWhile((char c) => isAlphaNum(c) || c == '_');
                TokenType kind = canFind(keywordList, word) ? TokenType.KEYWORD : TokenType.IDENTIFIER;
                current = Token(kind, word);
                return;
            }

            index++;
        }
    }

    /**
     * Returns the type of the current token.
     */
    public TokenType getTokenType() {
        return current.type;
    }

    /**
     * Returns the text value of the current token.
     */
    public string getTokenValue() {
        return current.value;
    }

    /**
     * Skips whitespace characters in the source text.
     */
    private void skipSpaces() {
        while (index < source.length && isWhite(source[index])) {
            index++;
        }
    }

    /**
     * Helper function for reading a sequence of characters as long as a condition is met.
     */
    private string readWhile(bool delegate(char) predicate) {
        size_t start = index;
        while (index < source.length && predicate(source[index])) {
            index++;
        }
        return source[start .. index];
    }
}

/**
 * Function to convert problematic XML characters (like < or &) into safe representations within XML tags.
 */
string escapeXml(string value) {
    switch (value) {
        case "<":  return "&lt;";
        case ">":  return "&gt;";
        case "\"": return "&quot;";
        case "&":  return "&amp;";
        default:   return value;
    }
}

/**
 * Function that processes a single Jack file and generates an output file in XML format.
 */
void processFile(string inputPath) {
    string outputPath = stripExtension(inputPath) ~ "T.My.xml";
    
    auto tokenizer = new JackTokenizer(inputPath);
    auto writer = File(outputPath, "w");

    writer.writeln("<tokens>");

    while (tokenizer.hasMoreTokens()) {
        tokenizer.advance();
        TokenType tType = tokenizer.getTokenType();
        string tVal = tokenizer.getTokenValue();

        string line;
        final switch (tType) {
            case TokenType.KEYWORD:
                line = "<keyword> " ~ escapeXml(tVal) ~ " </keyword>";
                break;
            case TokenType.SYMBOL:
                line = "<symbol> " ~ escapeXml(tVal) ~ " </symbol>";
                break;
            case TokenType.IDENTIFIER:
                line = "<identifier> " ~ escapeXml(tVal) ~ " </identifier>";
                break;
            case TokenType.INT_CONST:
                line = "<integerConstant> " ~ escapeXml(tVal) ~ " </integerConstant>";
                break;
            case TokenType.STRING_CONST:
                line = "<stringConstant> " ~ escapeXml(tVal) ~ " </stringConstant>";
                break;
        }
        writer.writeln(line);
    }

    writer.writeln("</tokens>");
    writer.close();
    writefln("Success! Token file created: %s", outputPath);
}

// כניסת התוכנית: קריאה של קובץ בודד או תיקיה
version (JackTokenizerMain)
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