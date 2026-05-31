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

// טוקנייזר ראשי לקבצי Jack
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

// המרה של תווי XML בעייתיים לייצוג בטוח
string escapeXml(string value) {
    switch (value) {
        case "<":  return "&lt;";
        case ">":  return "&gt;";
        case "\"": return "&quot;";
        case "&":  return "&amp;";
        default:   return value;
    }
}

// יצירת קובץ XML עבור קובץ Jack יחיד
void processFile(string inputPath) {
    // בניית שם קובץ פלט מדויק ללא נקודה כפולה: SquareT.My.xml
    string outputPath = stripExtension(inputPath) ~ "T.My.xml";
    
    auto tokenizer = new JackTokenizer(inputPath);
    auto writer = File(outputPath, "w"); // מצב "w" מוחק תוכן ישן וכותב מחדש

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
                // במחרוזות (stringConstant) אין צורך בגרשיים בפלט עצמו, אך הרווחים סביבו נשמרים
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