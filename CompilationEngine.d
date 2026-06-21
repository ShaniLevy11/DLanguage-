module CompilationEngine;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.conv; // הוספנו עבור המרות to!int ו- to!string

import Ex4.JackTokenizer;
import Ex4.SymbolTable; // בהנחה שזה שם המודול שלך
import Ex4.VMWriter;    // בהנחה שזה שם המודול שלך

class CompilationEngine {
    private JackTokenizer tokenizer;
    private File writer; // לטובת פלט ה-XML
    private size_t indentLevel = 0;
    private string indentUnit = "  ";

    // תוספות עבור פרויקט 11:
    private VMWriter vmWriter;
    private SymbolTable symbolTable;
    private string className;
    private int whileLabelIndex = 0;
    private int ifLabelIndex = 0;

    private static const string[] opList = ["+", "-", "*", "/", "&", "|", "<", ">", "="];

    // עדכון הקונסטרקטור שיקבל את התלויות החדשות
    this(JackTokenizer tokenizer, string xmlOutputPath, VMWriter vmWriter, SymbolTable symbolTable) {
        this.tokenizer = tokenizer;
        this.writer = File(xmlOutputPath, "w");
        this.vmWriter = vmWriter;
        this.symbolTable = symbolTable;
    }

    // --- פונקציות העזר ל-XML (נשארו כפי שהיו) ---
    private void processSymbol(string expectedSymbol) {
        if (tokenizer.getTokenType() == TokenType.SYMBOL && tokenizer.getTokenValue() == expectedSymbol) {
            writeLine("<symbol> " ~ escapeXml(expectedSymbol) ~ " </symbol>");
            if (tokenizer.hasMoreTokens()) tokenizer.advance();
        } else {
            writeln("Syntax Error: Expected symbol " ~ expectedSymbol ~ " but got " ~ tokenizer.getTokenValue());
        }
    }

    private void processKeyword(string expectedKeyword) {
        if (tokenizer.getTokenType() == TokenType.KEYWORD && tokenizer.getTokenValue() == expectedKeyword) {
            writeLine("<keyword> " ~ expectedKeyword ~ " </keyword>");
            if (tokenizer.hasMoreTokens()) tokenizer.advance();
        } else {
            writeln("Syntax Error: Expected keyword " ~ expectedKeyword);
        }
    }

    private void processIdentifier() {
        if (tokenizer.getTokenType() == TokenType.IDENTIFIER) {
            writeLine("<identifier> " ~ tokenizer.getTokenValue() ~ " </identifier>");
            if (tokenizer.hasMoreTokens()) tokenizer.advance();
        } else {
            writeln("Syntax Error: Expected identifier");
        }
    }

    private void openTag(string tagName) {
        writeLine("<" ~ tagName ~ ">");
        indentLevel++;
    }

    private void closeTag(string tagName) {
        if (indentLevel > 0) {
            indentLevel--;
        }
        writeLine("</" ~ tagName ~ ">");
    }

    private void writeLine(string line) {
        writer.writeln(makeIndent() ~ line);
    }

    private string makeIndent() {
        auto buf = appender!string;
        for (size_t i = 0; i < indentLevel; i++) {
            buf.put(indentUnit);
        }
        return buf.data.idup;
    }

    // פונקציית עזר לפרויקט 11: המרת Enum של מחלקה למחרוזת הסגמנט
    private string getSegment(SymbolKind kind) {
        switch (kind) {
            case SymbolKind.STATIC: return "static";
            case SymbolKind.FIELD: return "this";
            case SymbolKind.ARGUMENT: return "argument";
            case SymbolKind.LOCAL: return "local";
            default: return "";
        }
    }

    // --- פונקציות הקומפילציה ---

    public void compileClass() {
        openTag("class");
        processKeyword("class");
        
        className = tokenizer.getTokenValue(); // שמירת שם המחלקה
        processIdentifier();
        processSymbol("{");

        while (tokenizer.hasMoreTokens() && 
               (tokenizer.getTokenValue() == "static" || tokenizer.getTokenValue() == "field")) {
            compileClassVarDec();
        }

        while (tokenizer.hasMoreTokens() && 
               (tokenizer.getTokenValue() == "constructor" || 
                tokenizer.getTokenValue() == "function" || 
                tokenizer.getTokenValue() == "method")) {
            compileSubroutine();
        }

        processSymbol("}");
        closeTag("class");
        writer.close();
    }

    public void compileClassVarDec() {
        openTag("classVarDec");
        
        string kindStr = tokenizer.getTokenValue();
        SymbolKind kind = (kindStr == "static") ? SymbolKind.STATIC : SymbolKind.FIELD;
        processKeyword(kindStr);

        string typeStr = tokenizer.getTokenValue();
        if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(typeStr);
        else processIdentifier();

        string varName = tokenizer.getTokenValue();
        symbolTable.define(varName, typeStr, kind);
        processIdentifier();

        while (tokenizer.getTokenValue() == ",") {
            processSymbol(",");
            
            varName = tokenizer.getTokenValue();
            symbolTable.define(varName, typeStr, kind);
            processIdentifier();
        }
        processSymbol(";");
        closeTag("classVarDec");
    }

    public void compileSubroutine() {
        openTag("subroutineDec");
        symbolTable.startSubroutine(); // איפוס הטבלה הלוקאלית

        string subroutineKind = tokenizer.getTokenValue(); // constructor | function | method
        processKeyword(subroutineKind);

        string returnType = tokenizer.getTokenValue();
        if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(returnType);
        else processIdentifier();

        string subroutineName = tokenizer.getTokenValue();
        processIdentifier();

        if (subroutineKind == "method") {
            symbolTable.define("this", className, SymbolKind.ARGUMENT);
        }

        processSymbol("(");
        compileParameterList();
        processSymbol(")");
        
        // מעביר את הסוג והשם הלאה כדי שנוכל לייצר את הפקודה VM הנכונה בתוך הגוף
        compileSubroutineBody(subroutineName, subroutineKind);
        closeTag("subroutineDec");
    }

    public void compileParameterList() {
        openTag("parameterList");
        if (tokenizer.getTokenValue() != ")") {
            string typeStr = tokenizer.getTokenValue();
            if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(typeStr);
            else processIdentifier();

            string varName = tokenizer.getTokenValue();
            symbolTable.define(varName, typeStr, SymbolKind.ARGUMENT);
            processIdentifier();

            while (tokenizer.getTokenValue() == ",") {
                processSymbol(",");
                
                string extTypeStr = tokenizer.getTokenValue();
                if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(extTypeStr);
                else processIdentifier();
                
                string extVarName = tokenizer.getTokenValue();
                symbolTable.define(extVarName, extTypeStr, SymbolKind.ARGUMENT);
                processIdentifier();
            }
        }
        closeTag("parameterList");
    }

    public void compileSubroutineBody(string subroutineName, string subroutineKind) {
        openTag("subroutineBody");
        processSymbol("{");

        while (tokenizer.getTokenValue() == "var") {
            compileVarDec();
        }

        // --- הזרקת קוד פרויקט 11: הצהרת הפונקציה ואתחול זיכרון ---
        int nLocals = symbolTable.varCount(SymbolKind.LOCAL);
        vmWriter.writeFunction(className ~ "." ~ subroutineName, nLocals);

        if (subroutineKind == "constructor") {
            int nFields = symbolTable.varCount(SymbolKind.FIELD);
            vmWriter.writePush("constant", nFields);
            vmWriter.writeCall("Memory.alloc", 1);
            vmWriter.writePop("pointer", 0); // מעגן את This
        } else if (subroutineKind == "method") {
            vmWriter.writePush("argument", 0);
            vmWriter.writePop("pointer", 0); // מעגן את This לארגומנט המוסתר 0
        }

        compileStatements();
        processSymbol("}");
        closeTag("subroutineBody");
    }

    public void compileVarDec() {
        openTag("varDec");
        processKeyword("var");

        string typeStr = tokenizer.getTokenValue();
        if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(typeStr);
        else processIdentifier();

        string varName = tokenizer.getTokenValue();
        symbolTable.define(varName, typeStr, SymbolKind.LOCAL);
        processIdentifier();

        while (tokenizer.getTokenValue() == ",") {
            processSymbol(",");
            
            varName = tokenizer.getTokenValue();
            symbolTable.define(varName, typeStr, SymbolKind.LOCAL);
            processIdentifier();
        }
        processSymbol(";");
        closeTag("varDec");
    }

    public void compileStatements() {
        openTag("statements");
        while (tokenizer.hasMoreTokens()) {
            string val = tokenizer.getTokenValue();
            if (val == "let") compileLet();
            else if (val == "if") compileIf();
            else if (val == "while") compileWhile();
            else if (val == "do") compileDo();
            else if (val == "return") compileReturn();
            else break;
        }
        closeTag("statements");
    }

    public void compileLet() {
        openTag("letStatement");
        processKeyword("let");
        
        string varName = tokenizer.getTokenValue();
        processIdentifier();

        bool isArray = false;
        if (tokenizer.getTokenValue() == "[") {
            isArray = true;
            
            // חישוב מערך: דחיפת כתובת הבסיס
            SymbolInfo* info = symbolTable.lookup(varName);
            if (info !is null) vmWriter.writePush(getSegment(info.kind), info.index);

            processSymbol("[");
            compileExpression(); // דוחף את האינדקס
            processSymbol("]");
            
            vmWriter.writeArithmetic("ADD");
        }

        processSymbol("=");
        compileExpression(); // דוחף את התוצאה
        processSymbol(";");
        
        if (isArray) {
            // טריק להשמה לתוך מערך
            vmWriter.writePop("temp", 0);
            vmWriter.writePop("pointer", 1);
            vmWriter.writePush("temp", 0);
            vmWriter.writePop("that", 0);
        } else {
            // השמה למשתנה רגיל
            SymbolInfo* info = symbolTable.lookup(varName);
            if (info !is null) vmWriter.writePop(getSegment(info.kind), info.index);
        }

        closeTag("letStatement");
    }

    public void compileIf() {
        openTag("ifStatement");
        
        int index = ifLabelIndex++;
        string labelTrue = "IF_TRUE" ~ to!string(index);
        string labelFalse = "IF_FALSE" ~ to!string(index);
        string labelEnd = "IF_END" ~ to!string(index);

        processKeyword("if");
        processSymbol("(");
        compileExpression();
        processSymbol(")");
        
        vmWriter.writeIf(labelTrue);
        vmWriter.writeGoto(labelFalse);
        vmWriter.writeLabel(labelTrue);

        processSymbol("{");
        compileStatements();
        processSymbol("}");

        if (tokenizer.getTokenValue() == "else") {
            vmWriter.writeGoto(labelEnd);
            vmWriter.writeLabel(labelFalse);
            
            processKeyword("else");
            processSymbol("{");
            compileStatements();
            processSymbol("}");
            
            vmWriter.writeLabel(labelEnd);
        } else {
            vmWriter.writeLabel(labelFalse);
        }
        
        closeTag("ifStatement");
    }

    public void compileWhile() {
        openTag("whileStatement");
        
        int index = whileLabelIndex++;
        string labelExp = "WHILE_EXP" ~ to!string(index);
        string labelEnd = "WHILE_END" ~ to!string(index);

        vmWriter.writeLabel(labelExp);
        processKeyword("while");
        processSymbol("(");
        compileExpression();
        processSymbol(")");
        
        vmWriter.writeArithmetic("NOT");
        vmWriter.writeIf(labelEnd);

        processSymbol("{");
        compileStatements();
        processSymbol("}");
        
        vmWriter.writeGoto(labelExp);
        vmWriter.writeLabel(labelEnd);

        closeTag("whileStatement");
    }

    public void compileDo() {
        openTag("doStatement");
        processKeyword("do");
        
        string firstIdentifier = tokenizer.getTokenValue();
        processIdentifier();
        
        string nameOfCall;
        int argCountOffset = 0;
        
        if (tokenizer.getTokenValue() == ".") {
            processSymbol(".");
            string subroutineName = tokenizer.getTokenValue();
            processIdentifier();
            
            SymbolInfo* info = symbolTable.lookup(firstIdentifier);
            if (info !is null) {
                vmWriter.writePush(getSegment(info.kind), info.index);
                nameOfCall = info.typeStr ~ "." ~ subroutineName;
                argCountOffset = 1;
            } else {
                nameOfCall = firstIdentifier ~ "." ~ subroutineName;
            }
        } else {
            vmWriter.writePush("pointer", 0);
            nameOfCall = className ~ "." ~ firstIdentifier;
            argCountOffset = 1;
        }

        processSymbol("(");
        int nArgs = compileExpressionList();
        processSymbol(")");
        processSymbol(";");
        
        vmWriter.writeCall(nameOfCall, nArgs + argCountOffset);
        vmWriter.writePop("temp", 0); // זורק את ערך החזרה לפח
        
        closeTag("doStatement");
    }

    public void compileReturn() {
        openTag("returnStatement");
        processKeyword("return");
        
        if (tokenizer.getTokenValue() != ";") {
            compileExpression();
        } else {
            vmWriter.writePush("constant", 0); // מחזיר 0 בפונקציות void
        }
        processSymbol(";");
        vmWriter.writeReturn();
        
        closeTag("returnStatement");
    }

    public void compileExpression() {
        openTag("expression");
        compileTerm();

        while (canFind(opList, tokenizer.getTokenValue())) {
            string op = tokenizer.getTokenValue();
            processSymbol(op);
            compileTerm();
            
            switch (op) {
                case "+": vmWriter.writeArithmetic("ADD"); break;
                case "-": vmWriter.writeArithmetic("SUB"); break;
                case "*": vmWriter.writeCall("Math.multiply", 2); break;
                case "/": vmWriter.writeCall("Math.divide", 2); break;
                case "&": vmWriter.writeArithmetic("AND"); break;
                case "|": vmWriter.writeArithmetic("OR"); break;
                case "<": vmWriter.writeArithmetic("LT"); break;
                case ">": vmWriter.writeArithmetic("GT"); break;
                case "=": vmWriter.writeArithmetic("EQ"); break;
                default: break;
            }
        }
        closeTag("expression");
    }

    public void compileTerm() {
        openTag("term");
        TokenType type = tokenizer.getTokenType();
        string val = tokenizer.getTokenValue();

        if (type == TokenType.INT_CONST) {
            vmWriter.writePush("constant", to!int(val));
            writeLine("<integerConstant> " ~ val ~ " </integerConstant>");
            tokenizer.advance();
        } else if (type == TokenType.STRING_CONST) {
            vmWriter.writePush("constant", cast(int)val.length);
            vmWriter.writeCall("String.new", 1);
            foreach (char c; val) {
                vmWriter.writePush("constant", cast(int)c);
                vmWriter.writeCall("String.appendChar", 2);
            }
            writeLine("<stringConstant> " ~ escapeXml(val) ~ " </stringConstant>"); // מניח שיש לך את הפונקציה ב-JackTokenizer
            tokenizer.advance();
        } else if (type == TokenType.KEYWORD) {
            if (val == "true") {
                vmWriter.writePush("constant", 0);
                vmWriter.writeArithmetic("NOT");
            } else if (val == "false" || val == "null") {
                vmWriter.writePush("constant", 0);
            } else if (val == "this") {
                vmWriter.writePush("pointer", 0);
            }
            processKeyword(val);
        } else if (val == "(") {
            processSymbol("(");
            compileExpression();
            processSymbol(")");
        } else if (val == "-" || val == "~") {
            string unaryOp = val;
            processSymbol(val);
            compileTerm();
            if (unaryOp == "-") vmWriter.writeArithmetic("NEG");
            else vmWriter.writeArithmetic("NOT");
        } else if (type == TokenType.IDENTIFIER) {
            string firstIdentifier = val;
            processIdentifier();
            string nextVal = tokenizer.getTokenValue();
            
            if (nextVal == "[") {
                SymbolInfo* info = symbolTable.lookup(firstIdentifier);
                if (info !is null) vmWriter.writePush(getSegment(info.kind), info.index);
                
                processSymbol("[");
                compileExpression();
                processSymbol("]");
                
                vmWriter.writeArithmetic("ADD");
                vmWriter.writePop("pointer", 1);
                vmWriter.writePush("that", 0);
            } else if (nextVal == "(") {
                vmWriter.writePush("pointer", 0);
                processSymbol("(");
                int nArgs = compileExpressionList();
                processSymbol(")");
                vmWriter.writeCall(className ~ "." ~ firstIdentifier, nArgs + 1);
            } else if (nextVal == ".") {
                processSymbol(".");
                string subroutineName = tokenizer.getTokenValue();
                processIdentifier();
                processSymbol("(");
                
                string nameOfCall;
                int argCountOffset = 0;
                SymbolInfo* info = symbolTable.lookup(firstIdentifier);
                
                if (info !is null) {
                    vmWriter.writePush(getSegment(info.kind), info.index);
                    nameOfCall = info.typeStr ~ "." ~ subroutineName;
                    argCountOffset = 1;
                } else {
                    nameOfCall = firstIdentifier ~ "." ~ subroutineName;
                }
                
                int nArgs = compileExpressionList();
                processSymbol(")");
                vmWriter.writeCall(nameOfCall, nArgs + argCountOffset);
            } else {
                SymbolInfo* info = symbolTable.lookup(firstIdentifier);
                if (info !is null) vmWriter.writePush(getSegment(info.kind), info.index);
            }
        }
        closeTag("term");
    }

    public int compileExpressionList() {
        openTag("expressionList");
        int count = 0;
        if (tokenizer.getTokenValue() != ")") {
            compileExpression();
            count++;
            while (tokenizer.getTokenValue() == ",") {
                processSymbol(",");
                compileExpression();
                count++;
            }
        }
        closeTag("expressionList");
        return count; // מחזירים את המספר כדי לדעת כמה פרמטרים הועברו ב-Call
    }
}