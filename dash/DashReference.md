# Dash Reference

-----
## 概要
プログラミング言語Dashの仕様

-----
## 例
dash_sample.cを見よ

-----
## 構文
main関数から始まる。
グローバルには関数しか書けない。

### 四則演算
+ - * /  
TODO MOD

### 比較
== > >= 
TODO (< <=)

### 論理演算
TODO (&& ||)

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
}
```
TODO (break)

### 関数
```
func(a, b, c) {
    a = calc(a, c);

    return (a, b);
}
```

### リスト
(1, (2, 3))
car(x), cdr(y)

### プリミティブ
TODO (atom(x))

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


