module EX5.CompilationEngine;

import std.stdio;
import std.string;
import std.algorithm;
import Ex4.JackTokenizer;
import EX5.build.rsp.symbolTable;
import EX5.VMWriter;

class CompilationEngine {
    private JackTokenizer tokenizer;
    private VMWriter vm;
    private SymbolTable st;
    private string className;
    private int labelIndex = 0;

    this(JackTokenizer tokenizer, string outputPath) {
        this.tokenizer = tokenizer;
        this.vm = new VMWriter(outputPath);
        this.st = new SymbolTable();
    }

    public void compileClass() {
        tokenizer.advance(); // class
        className = tokenizer.getTokenValue();
        tokenizer.advance(); // name
        tokenizer.advance(); // {

        while (tokenizer.hasMoreTokens() && (tokenizer.getTokenValue() == "static" || tokenizer.getTokenValue() == "field")) {
            compileClassVarDec();
        }

        while (tokenizer.hasMoreTokens() && (tokenizer.getTokenValue() == "constructor" || tokenizer.getTokenValue() == "function" || tokenizer.getTokenValue() == "method")) {
            compileSubroutine();
        }
        vm.close();
    }

    public void compileClassVarDec() {
        SymbolKind kind = (tokenizer.getTokenValue() == "static") ? SymbolKind.STATIC : SymbolKind.FIELD;
        tokenizer.advance(); // static/field
        string type = tokenizer.getTokenValue();
        tokenizer.advance(); // type
        string name = tokenizer.getTokenValue();
        tokenizer.advance(); // name
        st.define(name, type, kind);

        while (tokenizer.getTokenValue() == ",") {
            tokenizer.advance(); // ,
            name = tokenizer.getTokenValue();
            tokenizer.advance(); // name
            st.define(name, type, kind);
        }
        tokenizer.advance(); // ;
    }

    public void compileSubroutine() {
        st.startSubroutine();
        string subType = tokenizer.getTokenValue();
        tokenizer.advance(); // method/function/constructor
        tokenizer.advance(); // return type
        string subName = tokenizer.getTokenValue();
        tokenizer.advance(); // name
        
        if (subType == "method") st.define("this", className, SymbolKind.ARGUMENT);

        tokenizer.advance(); // (
        compileParameterList();
        tokenizer.advance(); // )
        tokenizer.advance(); // {
        
        while (tokenizer.getTokenValue() == "var") compileVarDec();

        vm.writeFunction(className ~ "." ~ subName, st.varCount(SymbolKind.LOCAL));

        if (subType == "method") {
            vm.writePush("argument", 0);
            vm.writePop("pointer", 0);
        } else if (subType == "constructor") {
            vm.writePush("constant", st.varCount(SymbolKind.FIELD));
            vm.writeCall("Memory.alloc", 1);
            vm.writePop("pointer", 0);
        }

        compileStatements();
        tokenizer.advance(); // }
    }

    public void compileVarDec() {
        tokenizer.advance(); // var
        string type = tokenizer.getTokenValue();
        tokenizer.advance(); // type
        string name = tokenizer.getTokenValue();
        tokenizer.advance(); // name
        st.define(name, type, SymbolKind.LOCAL);
        while (tokenizer.getTokenValue() == ",") {
            tokenizer.advance(); // ,
            name = tokenizer.getTokenValue();
            tokenizer.advance(); // name
            st.define(name, type, SymbolKind.LOCAL);
        }
        tokenizer.advance(); // ;
    }

    public void compileStatements() {
        while (tokenizer.hasMoreTokens()) {
            string val = tokenizer.getTokenValue();
            if (val == "let") compileLet();
            else if (val == "if") compileIf();
            else if (val == "while") compileWhile();
            else if (val == "do") compileDo();
            else if (val == "return") compileReturn();
            else break;
        }
    }

    public void compileReturn() {
        tokenizer.advance(); // return
        if (tokenizer.getTokenValue() != ";") compileExpression();
        else vm.writePush("constant", 0);
        vm.writeReturn();
        tokenizer.advance(); // ;
    }

    // כאן תמשיך את המימוש של compileLet, compileIf, compileWhile, compileDo 
    // ע"י החלפת ה-processX בשימוש ב-vm.writeX ו-st.lookup(name)
}