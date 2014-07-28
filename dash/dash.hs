import Data.IORef
import Control.Applicative ((<$>))
import Text.ParserCombinators.Parsec hiding (spaces)
import Text.ParserCombinators.Parsec.Expr
import qualified Text.ParserCombinators.Parsec.Token as P
import Text.ParserCombinators.Parsec.Language
import qualified Data.Map as M
import Debug.Trace

import Data.List
import Data.Maybe


--------------------------------------------------
-- Parsec
--------------------------------------------------
lexer  = P.makeTokenParser(emptyDef)
number = P.natural lexer
parens = P.parens lexer
braces = P.braces lexer
natural = P.natural lexer
identifier = P.identifier lexer
reservedOp = P.reservedOp lexer
whiteSpace = P.whiteSpace lexer

data Dash = Empty
  | Code [Dash]
  | Function Dash Dash Dash
  | VarList [Dash]
  | CompoundStatement [Dash]
  | Assign Dash Dash
  | If Dash Dash Dash
  | While Dash Dash
  | Op String Dash Dash
  | Uop String Dash
  | Return Dash
  | Var String
  | Int Int
  | FunCall Dash Dash
  | Cons Dash Dash
  | Debug Dash
  | Break
  deriving Show

code :: Parser Dash
code = do
	x <- many (try function)
	whiteSpace
	eof
	return $ Code x

function :: Parser Dash
function = do
	name <- var
	whiteSpace
	char '('
	v <- varlist
	whiteSpace
	char ')'
	stmt <- compoundStatement
	return $ Function name v stmt

varlist :: Parser Dash
varlist = do
	v <- var
	vs <- many (do
			whiteSpace
			char ','
			var)
	return (VarList (v:vs))

var :: Parser Dash
var = do
	whiteSpace
	s <- identifier
	return $ Var s

compoundStatement = do
	whiteSpace
	char '{'
	whiteSpace
	stmt <- many statement
	whiteSpace
	char '}'
	return $ CompoundStatement stmt

statement = do
	try compoundStatement
    <|> try debug
	<|> try selection
	<|> try iteration
	<|> try returning
	<|> try expressionStatement

debug = do
    whiteSpace
    string "DEBUG"
    whiteSpace
    char '('
    e <- expression
    whiteSpace
    char ')'
    return (Debug e)

expressionStatement = do
	try (do
	whiteSpace
	char ';'
	whiteSpace
	return Empty)
	<|> try (do
	whiteSpace
	e <- expression
	whiteSpace
	char ';'
	whiteSpace
	return e)


expression :: Parser Dash
expression = do
	try (do
		whiteSpace
		v <- var
		whiteSpace
		char '='
		whiteSpace
		x <- lor
		whiteSpace
		return $ Assign v x)
	<|> try lor

expressionList = do
	x <- expression
	xs <- many (do
		whiteSpace
		char ','
		whiteSpace
		y <- expression
		whiteSpace
		return (\x -> Op "," x y))
	return $ foldl (\acc y -> y acc) x xs

lor = do
	x <- land
	xs <- many (do
		whiteSpace
		string "||"
		whiteSpace
		y <- land
		whiteSpace
		return (\x -> Op "||" x y))
	return $ foldl (\acc y -> y acc) x xs

land = do
	x <- equality
	xs <- many (do
		whiteSpace
		string "&&"
		whiteSpace
		y <- equality
		whiteSpace
		return (\x -> Op "&&" x y))
	return $ foldl (\acc y -> y acc) x xs

equality = do
	x <- relation
	xs <- many (do
		whiteSpace
		op <- equalityOp
		whiteSpace
		y <- relation
		whiteSpace
		return (\x -> Op op x y))
	return $ foldl (\acc y -> y acc) x xs

equalityOp = do
	whiteSpace
	(try (string "==")
		<|> try (string "!="))

relation = do
	x <- add
	xs <- many (do
		whiteSpace
		op <- relationOp
		whiteSpace
		y <- add
		whiteSpace
		return (\x -> Op op x y))
	return $ foldl (\acc y -> y acc) x xs
relationOp = do
	whiteSpace
	(try (string "<=")
		<|> try (string ">=")
		<|> try (string ">")
		<|> try (string "<"))

add = do
	whiteSpace
	x <- mul
	whiteSpace
	xs <- many (do
		whiteSpace
		op <- (try (string "+") <|> (try (string "-")))
		whiteSpace
		y <- mul
		whiteSpace
		return (\x -> Op op x y))
	return $ foldl (\acc y -> y acc) x xs

mul = do
	whiteSpace
	x <- unary
	whiteSpace
	xs <- many (do
		whiteSpace
		op <- (try (string "*") <|> (try (string "/")))
		whiteSpace
		y <- unary
		whiteSpace
		return (\x -> Op op x y))
	return $ foldl (\acc y -> y acc) x xs

unary = do
	whiteSpace
	x <- many (do
		whiteSpace
		op <- (try (string "+")
			<|> (try (string "-"))
			<|> (try (string "++"))
			<|> (try (string "--")))
		return (\y -> Uop op y))
	y <- postfixExpr
	return $ foldr (\f acc -> f acc) y x

postfixExpr = do
	whiteSpace
	x <- primaryExpr
	whiteSpace
	y <- many (do
		whiteSpace
		op <- (try (string "++"))
			<|> (try (string "--"))
		return (\y -> Uop op y))
	return $ foldl (\acc f -> f acc) x y

primaryExpr = do
	try (do
		whiteSpace
		n <- natural
		return (Int (fromIntegral n)))
    <|> try (do -- cons cell
        whiteSpace
        x <- consCell
        return x
        )
	<|> try (do -- car
		whiteSpace
		string "car"
		whiteSpace
		char '('
		e <- expression
		whiteSpace
		char ')'
		whiteSpace
		return (Uop "Car" e))
	<|> try (do -- cdr
		whiteSpace
		string "cdr"
		whiteSpace
		char '('
		e <- expression
		whiteSpace
		char ')'
		return (Uop "Cdr" e))
  <|> try (do -- atom
    whiteSpace
    string "atom"
    whiteSpace
    char '('
    e <- expression
    whiteSpace
    char ')'
    whiteSpace
    return (Uop "Atom" e))
	<|> try (do
		whiteSpace
		char '('
		whiteSpace
		e <- expression
		whiteSpace
		char ')'
		whiteSpace
		return e)
	<|> try (do
		whiteSpace
		v <- var
		whiteSpace
		char '('
		sl <- expressionList
		whiteSpace
		char ')'
		return (FunCall v sl))
	<|> (do
		whiteSpace
		var)

consCell = do
	whiteSpace
	char '('
	whiteSpace
	carVal <- expression
	whiteSpace
	char ','
	whiteSpace
	cdrVal <- expression
	whiteSpace
	char ')'
	whiteSpace
	return $ Cons carVal cdrVal

selection = do
	whiteSpace
	string "if"
	whiteSpace
	char '('
	whiteSpace
	cond <- expression
	whiteSpace
	char ')'
	whiteSpace
	stmt <- statement
	(try (do
		whiteSpace
		string "else"
		whiteSpace
		stmt2 <- statement
		whiteSpace
		return (If cond stmt stmt2))
	 <|> (return (If cond stmt Empty)))

iteration = do
	whiteSpace
	string "while"
	whiteSpace
	char '('
	whiteSpace
	cond <- expression
	whiteSpace
	char ')'
	whiteSpace
	stmt <- statement
	return $ While cond stmt

returning = do
	whiteSpace
	string "return"
	whiteSpace
	e <- expressionStatement
	return $ Return e

--------------------------------------------------
-- Print GCC
--------------------------------------------------
data Env = Env { line::Int,
		func::[(String, Int)],
		val::[String] } deriving Show

envSetVal env v = Env (line env) (func env) v
envSetLine env n = Env n (func env) (val env)
getValPosition env name = fromJust $ elemIndex name (val env)
envAddLine env n = Env (line env + n) (func env) (val env)
envAddFunc env a = Env (line env) (a:func env) (val env)

addHeadComment (c:cs) s = (c++s):cs

initialEnv = Env 0 [] []


eval :: Dash -> Env -> ([String], Env)

eval (Code []) env = ([], env)
eval (Code ((Function (Var name) (VarList vl) stmt):xs)) env =
	let env' = envAddFunc env (name, (line env))
	    env1 = envSetVal env' (map (\(Var s) -> s) vl)
	    (c2, env2) = eval stmt env1
	    (c3, env3) = eval (Code xs) env2
	    c2' = addHeadComment c2 ("\t;; Start " ++ name)
	in (c2'++c3, env3)

eval (CompoundStatement []) env = ([], env)
eval (CompoundStatement (x:xs)) env =
	let (c1, env1) = eval x env
	    (c2, env2) = eval (CompoundStatement xs) env1
	in (c1 ++ c2, env2)

eval (Assign (Var a) e) env =
	let (c1, env1) = eval e env
	    z = "ST 0 " ++ show (getValPosition env1 a) ++
		    "\t;; [Line " ++ show (line env1) ++ "]"
	    env2 = envAddLine env1 1
	in (c1 ++ [z], env2)

eval (Op "," l r) env =
	let (c1, env1) = eval l env
	    (c2, env2) = eval r env1
	in (c1 ++ c2, env2)

eval (Op op l r) env =
	let (c1, env1) = eval l env
	    (c2, env2) = eval r env1
	    z = f op
	    env3 = envAddLine env2 1
	in (c1 ++ c2 ++ [z], env3)
	where f "+" = "ADD"
	      f "-" = "SUB"
	      f "*" = "MUL"
	      f "/" = "DIV"
	      f "==" = "CEQ"
	      f ">" = "CGT"
	      f ">=" = "CGTE"
	      f s = s

eval (Uop "Car" e) env =
	let (c1, env1) = eval e env
	    z = ["CAR" ++ "\t;; [Line " ++ show (line env1) ++ "]"]
	in (c1 ++ z, envAddLine env1 1)

eval (Uop "Cdr" e) env =
	let (c1, env1) = eval e env
	    z = ["CDR" ++ "\t;; [Line " ++ show (line env1) ++ "]"]
	in (c1 ++ z, envAddLine env1 1)

eval (Uop "Atom" e) env =
  let (c1, env1) = eval e env
      z = ["ATOM" ++ "\t;; [Line " ++ show (line env1) ++ "]"]
  in (c1 ++ z, envAddLine env1 1)

eval (Uop "-" e) env =
	let (c1, env1) = eval e env
	    z = ["LDC -1" ++ "\t;; [Line " ++ show (line env1) ++ "]",
		 "MUL"]
	in (c1 ++ z, envAddLine env1 2)

eval (Debug e) env =
    let (c1, env1) = eval e env
        z = ["DBUG" ++ "\t;; [DEBUG " ++ show e ++ "]"]
    in (c1 ++ z, envAddLine env1 2)

eval (If cond t f) env =
	let (c1, env1) = eval cond env
	    (c2, env2) = eval t (envAddLine env1 1)
	    (c3, env3) = eval f (envAddLine env2 2)
	    z = ["TSEL " ++ show (line env1 + 1) ++ " " ++
		    show (line env2 + 2) ++ "\t;; If"]
	    z2 = [ "LDC 0",
		  "TSEL " ++ show (line env3) ++
			 " " ++ show (line env3)]
	in (c1 ++ z ++ c2 ++ z2 ++ c3, env3)

eval (While cond stmt) env =
	let (c1, env1) = eval cond env
	    (c2, env2) = eval stmt (envAddLine env1 1)
	    env3 = envAddLine env2 2
	    z = ["TSEL " ++ show (line env1 + 1) ++
		     " " ++ show (line env2 + 2)]
	    z2 = ["LDC 0",
		  "TSEL " ++ show (line env) ++ " " ++
			show (line env)]
	in (c1 ++ z ++ c2 ++ z2, env3)

eval (Return s) env =
	let (c1, env1) = eval s env
	    z = "RTN" ++ "\t;; [Line " ++ show (line env1) ++ "]"
	in (c1 ++ [z], envAddLine env1 1)


eval (Int n) env =
	let z = "LDC " ++ show n ++
		    "\t;; [Line " ++ show (line env) ++ "]"
	in ([z], envAddLine env 1)

eval (Var v) env =
	if v `elem` (val env)
	then let z = ["LD 0 " ++ show (getValPosition env v)]
	     in (z, envAddLine env 1)
	else let z = ["LDF " ++ "___" ++ v ++ "___"]
	     in (z, envAddLine env 1)

eval (FunCall (Var name) stlist) env =
	let (c1, env1) = eval stlist env
	    z = "LDF " ++ "___" ++ name ++ "___"
	    z2 = "AP " ++ show (countComma stlist + 1)
	in (c1 ++ [z] ++ [z2], envAddLine env1 2)
	where countComma (Op "," l r) =
		      1 + countComma l + countComma r
	      countComma (Op _ l r) =
		      countComma l + countComma r
	      countComma _ = 0


eval (Cons carE cdrE) env =
	let (c1, env1) = eval carE env
	    (c2, env2) = eval cdrE env1
	    z = ["CONS" ++ "\t;; [Line " ++ show (line env2) ++ "]"]
	in (c1 ++ c2 ++ z, envAddLine env2 1)

eval Empty env = ([], env)

eval a env = (["##### NOP ##### " ++ show a], envAddLine env 1)

funcScore = map (\(x, y) -> ("___" ++ x ++ "___", y))

main = do
	str <- getContents
	let f (Right b) = putStr
		$ unlines $ map (unwords .map aa .words) ls
	     where (ls, env) = eval b initialEnv
		   aa s = case lookup s (funcScore (func env)) of
			       Just b -> show b
			       Nothing -> s
	    f (Left b) = print b
	--let f (Right b) = putStrLn (unlines .fst $ eval b initialEnv)
	f $ parse code "Dash" str
