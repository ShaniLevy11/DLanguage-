module Ex4.JackTokenizer;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.ascii;
import std.algorithm;
import std.array;
import std.format;

// סוגי הטוקנים האפשריים בשפת Jack
enum TokenType {
    KEYWORD,
    SYMBOL,
    IDENTIFIER,
    INT_CONST,
    STRING_CONST
}

// מייצג טוקן בודד עם סוג וערך
struct Token {
    TokenType type;
    string value;
}

// הסרה ידנית של הערות, תוך שמירה על מחרוזות תקינות
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
class JackTokenizer {
    private string source;
    private size_t index = 0;
    private Token current;

    private static const string[] keywordList = [
        "class", "constructor", "function", "method", "field",
        "static", "var", "int", "char", "boolean", "void",
        "true", "false", "null", "this", "let", "do",
        "if", "else", "while", "return"
    ];

    private static const char[] symbolList = [
        '{', '}', '(', ')', '[', ']', '.', ',', ';',
        '+', '-', '*', '/', '&', '|', '<', '>', '=', '~'
    ];

    this(string inputFilePath) {
        string rawText = readText(inputFilePath);
        this.source = stripComments(rawText);
    }

    public bool hasMoreTokens() {
        skipSpaces();
        return index < source.length;
    }

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
                index++; // פוסח על גרש פותח
                size_t start = index;
                while (index < source.length && source[index] != '"') {
                    index++;
                }
                string val = source[start .. index];
                if (index < source.length) {
                    index++; // פוסח על גרש סוגר
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

    public TokenType getTokenType() {
        return current.type;
    }

    public string getTokenValue() {
        return current.value;
    }

    private void skipSpaces() {
        while (index < source.length && isWhite(source[index])) {
            index++;
        }
    }

    private string readWhile(bool delegate(char) predicate) {
        size_t start = index;
        while (index < source.length && predicate(source[index])) {
            index++;
        }
        return source[start .. index];
    }
}
