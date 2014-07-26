# Dash Reference

-----
## 概要
プログラミング言語Dashの仕様

-----
## 構文
main関数から始まる。
グローバルには関数しか書けない。

### 四則演算
+ - * /
### 比較
== < > <= >=
### 論理演算
&& ||
### 代入
=
### 条件分岐
```
if (cond) {

} else {

}
```

### ループ
```
while (cond) {
    break;
}
```

### 関数
```
func(a, b, arr[8]) {
    arr[0] = calc(a, c);

    return (a, b);
}
```

### リスト
[a, b, [c, d]]  
cons, car, cdr

### プリミティブ
atom(x)

-----

## BNF
Code ::= <Function> *
Function ::= Id '(' <VarList> ')' <CompoundStatement>
VarList ::= <Var> (',' <Var>)*
Var ::= Id | <Array>
CompoundStatement ::= '{' <StatementList> '}'
StatementList ::= <Statement>*
Statement ::= <CompoundStatement> | <Expression> | <Selection> | <Iteration> | <Returning>
ExpressionStatement ::= ';' | <Expression> ';'
Expression ::= (<Var> '=')? <LOr>
LOr ::= <LAnd> {'||' <LAnd>}*
LAnd ::= <Equality> {'&&' <Equality>}*
Equality ::= <Relation> {('=='|'!=') <Relation>}*
Relation ::= <Add> {('<'|'>'|'<='|'>=') <Add>}*
Add ::= <Mul> {('+'|'-') <Mul>}*
Mul ::= <Unary> {('*'|'/') <Unary>}*
Unary ::= ('++'|'--'|<UnaryOp>)* <PostfixExpr>
PostfixExpr ::= <PrimaryExpr> ('++'|'--')*
PrimaryExpr ::= Id | Const | '(' Expression ')'

Selection ::= 'if' '(' <Expression> ')' <Statement> ('else' <Statement>)?
Iteration ::= 'while' '(' <Expression> ')' <Statement>
Returning ::= 'return' ExpressionStatement


