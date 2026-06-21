module nand2tetris.symboltable;

enum SymbolKind {
    STATIC, 
    FIELD, 
    ARGUMENT, 
    LOCAL,
    NONE
}

struct SymbolInfo {
    string typeStr;
    SymbolKind kind;
    int index;
}

class SymbolTable {
    private SymbolInfo[string] classTable;
    private SymbolInfo[string] subroutineTable;
    private int[SymbolKind] indices;

    this() {
        indices[SymbolKind.STATIC] = 0;
        indices[SymbolKind.FIELD] = 0;
        indices[SymbolKind.ARGUMENT] = 0;
        indices[SymbolKind.LOCAL] = 0;
    }

    // מאפס את הטבלה הלוקאלית בכניסה לפונקציה חדשה
    void startSubroutine() {
        subroutineTable.clear();
        indices[SymbolKind.ARGUMENT] = 0;
        indices[SymbolKind.LOCAL] = 0;
    }

    // מוסיף משתנה לטבלה המתאימה
    void define(string name, string typeStr, SymbolKind kind) {
        int idx = indices[kind]++;
        SymbolInfo info = SymbolInfo(typeStr, kind, idx);
        
        if (kind == SymbolKind.STATIC || kind == SymbolKind.FIELD) {
            classTable[name] = info;
        } else {
            subroutineTable[name] = info;
        }
    }

    int varCount(SymbolKind kind) {
        return indices.get(kind, 0);
    }

    // מחזיר מצביע למידע על המשתנה. שימוש באופרטור 'in' בשפת D הוא O(1) ומונע זריקת שגיאות
    SymbolInfo* lookup(string name) {
        if (auto p = name in subroutineTable) return p;
        if (auto p = name in classTable) return p;
        return null;
    }
}