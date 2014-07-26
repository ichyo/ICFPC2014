# GCC Reference

----------

## 概要
ICFPC2014のLambda-Man CPU上の言語 "General Compute coprocessor" (GCC) の仕様の和訳。

----------

## GCC
アセンブラ風スタック思考プログラミング言語。
逆ポーランド記法とか。
値はInt、Cons cell、関数。真偽値は0or1。
変数は関数の引数のみ。
関数は絶対アドレスで指定する。
関数はクロージャ。  

----------



## メモリスタック
3つのスタックがある。0 origin。Listだと思うと良い。

* Data Stack (DS)
* Control Stack (CS)
* Environment (Env)

----------


## レジスタ
4レジスタ

* %c control register (プログラムカウンタ)
* %s data stack register (データスタックのポインタ)
* %d control stack register (コントロールスタックのポインタ)
* %e environment frame register (環境スタックのポインタ)

## 環境
Environment  
フレームのリスト。
局所変数のために使われる。クロージャってやつ。  
関数を呼ぶたびに関数の引数をまとめてプッシュ。
DUMのあたりの命令見ないとわからない。


----------

## 命令
### ロード
* LDC n = (Int n) をDSにプッシュ
* LD n i = n番目のEnvのi番目の値をDSにプッシュ

### 演算
* ADD = y <- pop; x <- pop; push (x+y);
* SUB = y <- pop; x <- pop; push (x-y);
* MUL = y <- pop; x <- pop; push (x*y);
* DIV = y <- pop; x <- pop; push (x/y);
* CEQ = y <- pop; x <- pop; push (x==y);
* CEQ = y <- pop; x <- pop; push (x==y);
* CGT = y <- pop; x <- pop; push (x>y);
* CGTE = y <- pop; x <- pop; push (x>=y);
* ATOM = y <- pop; push (y is Int);
* CONS = y <- pop; x <- pop; push (Cons x y)
* CAR = x <- pop; (y, _) <- x; push y;
* CDR = x <- pop; (_, y) <- x; push y;

### ジャンプ
* SEL t f = x <- pop; PCを保存; if (x) then tにジャンプ else fにジャンプ;
* JOIN = x <- pop; xにジャンプ;

### 関数
* LDF f = 関数をDSにpush
* AP n = DSの先頭の関数をDSのn要素を引数に呼ぶ;
* RTN = プログラムカウンタをpop; main関数なら終了; そうでないならフレームのheadを戻す; 関数の呼び出し元に戻る;
* DUM n = サイズnのからのフレームを作る;
* RAP n = (Recursive AP) 
* STOP = STOP; //RTNを使用するべき。

## 末尾再帰拡張
* TSEL t f = x <- pop; if (x) then tにジャンプ else fにジャンプ; // PCを保存しない
* TAP n
* TRAP n

## Pascal拡張
* ST n i = DSの先頭をn番目のフレームのi番目に移す。

## Debug拡張
* DBUG = DSの先頭を出力(pop)
* BRK


----------

## TAG
### DS

* TAG_INT Int
* TAG_CONS List
* TAG_CLOSURE (PC, EnvPointer)

### CS

* TAG_STOP
* TAG_JOIN Int
* TAG_RET PC

### Env

* TAG_DUM EnvPointer



----------


## 使い方とか
DUP (DSの先頭をコピー) がない。そのため値を破壊せずに演算に使うことができない(スタックを消費する一方)。  
適当に2通り思いついた。

1. 環境フレームの値は何回でもロードできるので関数に潜り続ける
2. 関数に余分な引数をとっておき、ストアで局所変数として使う。

関数に潜ったとしても上の局所変数は見ることができる。
つまり関数に潜るというよりもブロックに潜るような感覚。



END  
