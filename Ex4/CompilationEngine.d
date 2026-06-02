module Ex4.CompilationEngine;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import Ex4.JackTokenizer;

class CompilationEngine {
    private JackTokenizer tokenizer;
    private File writer;
    private size_t indentLevel = 0;
    private string indentUnit = "  ";

    private static const string[] opList = ["+", "-", "*", "/", "&", "|", "<", ">", "="];

    this(JackTokenizer tokenizer, string outputPath) {
        this.tokenizer = tokenizer;
        this.writer = File(outputPath, "w");
    }

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

    public void compileClass() {
        openTag("class");
        processKeyword("class");
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
        processKeyword(tokenizer.getTokenValue());

        if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(tokenizer.getTokenValue());
        else processIdentifier();

        processIdentifier();

        while (tokenizer.getTokenValue() == ",") {
            processSymbol(",");
            processIdentifier();
        }
        processSymbol(";");
        closeTag("classVarDec");
    }

    public void compileSubroutine() {
        openTag("subroutineDec");
        processKeyword(tokenizer.getTokenValue());

        if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(tokenizer.getTokenValue());
        else processIdentifier();

        processIdentifier();
        processSymbol("(");
        compileParameterList();
        processSymbol(")");
        compileSubroutineBody();
        closeTag("subroutineDec");
    }

    public void compileParameterList() {
        openTag("parameterList");
        if (tokenizer.getTokenValue() != ")") {
            if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(tokenizer.getTokenValue());
            else processIdentifier();

            processIdentifier();

            while (tokenizer.getTokenValue() == ",") {
                processSymbol(",");
                if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(tokenizer.getTokenValue());
                else processIdentifier();
                processIdentifier();
            }
        }
        closeTag("parameterList");
    }

    public void compileSubroutineBody() {
        openTag("subroutineBody");
        processSymbol("{");

        while (tokenizer.getTokenValue() == "var") {
            compileVarDec();
        }

        compileStatements();
        processSymbol("}");
        closeTag("subroutineBody");
    }

    public void compileVarDec() {
        openTag("varDec");
        processKeyword("var");

        if (tokenizer.getTokenType() == TokenType.KEYWORD) processKeyword(tokenizer.getTokenValue());
        else processIdentifier();

        processIdentifier();

        while (tokenizer.getTokenValue() == ",") {
            processSymbol(",");
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
        processIdentifier();

        if (tokenizer.getTokenValue() == "[") {
            processSymbol("[");
            compileExpression();
            processSymbol("]");
        }

        processSymbol("=");
        compileExpression();
        processSymbol(";");
        closeTag("letStatement");
    }

    public void compileIf() {
        openTag("ifStatement");
        processKeyword("if");
        processSymbol("(");
        compileExpression();
        processSymbol(")");
        processSymbol("{");
        compileStatements();
        processSymbol("}");

        if (tokenizer.getTokenValue() == "else") {
            processKeyword("else");
            processSymbol("{");
            compileStatements();
            processSymbol("}");
        }
        closeTag("ifStatement");
    }

    public void compileWhile() {
        openTag("whileStatement");
        processKeyword("while");
        processSymbol("(");
        compileExpression();
        processSymbol(")");
        processSymbol("{");
        compileStatements();
        processSymbol("}");
        closeTag("whileStatement");
    }

    public void compileDo() {
        openTag("doStatement");
        processKeyword("do");
        processIdentifier();
        
        if (tokenizer.getTokenValue() == ".") {
            processSymbol(".");
            processIdentifier();
        }

        processSymbol("(");
        compileExpressionList();
        processSymbol(")");
        processSymbol(";");
        closeTag("doStatement");
    }

    public void compileReturn() {
        openTag("returnStatement");
        processKeyword("return");
        if (tokenizer.getTokenValue() != ";") {
            compileExpression();
        }
        processSymbol(";");
        closeTag("returnStatement");
    }

    public void compileExpression() {
        openTag("expression");
        compileTerm();

        while (canFind(opList, tokenizer.getTokenValue())) {
            processSymbol(tokenizer.getTokenValue());
            compileTerm();
        }
        closeTag("expression");
    }

    public void compileTerm() {
        openTag("term");
        TokenType type = tokenizer.getTokenType();
        string val = tokenizer.getTokenValue();

        if (type == TokenType.INT_CONST) {
            writeLine("<integerConstant> " ~ val ~ " </integerConstant>");
            tokenizer.advance();
        } else if (type == TokenType.STRING_CONST) {
            writeLine("<stringConstant> " ~ escapeXml(val) ~ " </stringConstant>");
            tokenizer.advance();
        } else if (type == TokenType.KEYWORD) {
            processKeyword(val);
        } else if (val == "(") {
            processSymbol("(");
            compileExpression();
            processSymbol(")");
        } else if (val == "-" || val == "~") {
            processSymbol(val);
            compileTerm();
        } else if (type == TokenType.IDENTIFIER) {
            processIdentifier();
            string nextVal = tokenizer.getTokenValue();
            if (nextVal == "[") {
                processSymbol("[");
                compileExpression();
                processSymbol("]");
            } else if (nextVal == "(") {
                processSymbol("(");
                compileExpressionList();
                processSymbol(")");
            } else if (nextVal == ".") {
                processSymbol(".");
                processIdentifier();
                processSymbol("(");
                compileExpressionList();
                processSymbol(")");
            }
        }
        closeTag("term");
    }

    public void compileExpressionList() {
        openTag("expressionList");
        if (tokenizer.getTokenValue() != ")") {
            compileExpression();
            while (tokenizer.getTokenValue() == ",") {
                processSymbol(",");
                compileExpression();
            }
        }
        closeTag("expressionList");
    }
}