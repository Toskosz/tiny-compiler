/* Analisador Sintatico e Semantico para Tiny */

%{
#include <stdio.h>
#include "semantic.h"
#include "codegen.h"
#include "Analisador-Lexico/symbol_table.h"

int yylex();
void yyerror(const char *s);
extern int yylineno;

int result = 0;
%}

%union {
    int ival;      // Para NUM
    char* sval;    // Para IDENTIFIER
    int tipo;      // Para tipo de expressão
}

%token NUM IDENTIFIER INTEGER ASSGNOP WHILE DO END ELSE FI IF IN LET PRINT READ SKIP THEN WRITE
%token <sval> LT GT EQ NEQ /* Relational Operators: < > = <> */
%token <sval> AND_OP OR_OP  /* Boolean Operators: && || */
%type <tipo> expression
%type <tipo> condition
%type <tipo> condition_statement
%type <sval> IDENTIFIER
%type <ival> NUM
%type <sval> relop
%left '-' '+' 
%left '*' '/' 
%right '^'

/* Para numeros negativos */
%precedence NEG

%%

/* Programa principal */
program:
    decls stmts { semantic_print_table(); }
;

decls: %empty 
    /* vazio */
  | decls decl
;

decl:
    INTEGER IDENTIFIER ';' { 
        semantic_declare_var($2, yylineno);
    }
;

stmts: %empty 
    /* vazio */
  | stmts stmt
;

relop:
      LT   { $$ = $1; }
    | GT   { $$ = $1; }
    | EQ   { $$ = $1; }
    | NEQ  { $$ = $1; }
;

condition:
    expression relop expression {
	/* Placeholder for semantic check and code generation */
        if ($1 != TYPE_INT || $3 != TYPE_INT) {
             printf("Erro semântico (linha %d): Operadores de condição requerem inteiros.\n", yylineno);
	     semantic_set_error();
        } else {
	     gen_relop($2); /* Generate code for the comparison */
             $$ = TYPE_INT; /* The result is an INTEGER (0 for false, 1 for true) */
	}
    }
;

condition_statement:
      condition
    | condition_statement AND_OP condition {
        if ($1 != TYPE_INT || $3 != TYPE_INT) { /* Check for INTEGER operands */
            printf("Erro semântico (linha %d): Operador '&&' requer operandos inteiros/booleanos.\n", yylineno);
            semantic_set_error();
            $$ = TYPE_VOID;
        } else {
            gen_op("AND");
            $$ = TYPE_INT; /* The result is an INTEGER */
        }
    }
    | condition_statement OR_OP condition {
        if ($1 != TYPE_INT || $3 != TYPE_INT) { /* Check for INTEGER operands */
            printf("Erro semântico (linha %d): Operador '||' requer operandos inteiros/booleanos.\n", yylineno);
            semantic_set_error();
            $$ = TYPE_VOID;
        } else {
            gen_op("OR");
            $$ = TYPE_INT;
        }
    }
;

/* Add these new empty rules that act as triggers for codegen */
M_start_loop: %empty { gen_loop_start(); } ;
M_after_condition: %empty { gen_after_condition(); } ;
M_end_loop: %empty { gen_loop_end(); } ;

stmt:
    IDENTIFIER ASSGNOP expression ';' {
        if (semantic_check_var($1, yylineno)) {
            int idx = find_symbol($1);
            gen_assign(symbol_table[idx].address);
        }
    }
  | WHILE M_start_loop condition_statement DO M_after_condition stmts END M_end_loop ';' { }
  | IF condition_statement THEN stmts END ';' { gen_if(); }
  | IF condition_statement THEN stmts ELSE stmts END ';' { gen_if_else(); }
  | READ IDENTIFIER ';' {
        if (semantic_check_var($2, yylineno)) {
            int idx = find_symbol($2);
            gen_read(symbol_table[idx].address);
        }
    }
  | WRITE expression ';' {
        gen_write();
    }
  | PRINT expression ';' {
        gen_write();
    }
;

/* Expressoes aceitas */
expression:
    '(' expression ')' { $$ = $2; }
  | '-' expression %prec NEG {
        if ($2 != TYPE_INT) {
            printf("Erro semântico (linha %d): Operação '-' requer inteiro.\n", yylineno);
            semantic_set_error();
            $$ = TYPE_VOID;
        } else {
            gen_neg();
            $$ = TYPE_INT;
        }
    }
  | expression '+' expression {
        if ($1 != TYPE_INT || $3 != TYPE_INT) {
            printf("Erro semântico (linha %d): Operação '+' requer inteiros.\n", yylineno);
            semantic_set_error();
            $$ = TYPE_VOID;
        } else {
            gen_op("ADD");
            $$ = TYPE_INT;
        }
    }
  | expression '-' expression {
        if ($1 != TYPE_INT || $3 != TYPE_INT) {
            printf("Erro semântico (linha %d): Operação '-' requer inteiros.\n", yylineno);
            semantic_set_error();
            $$ = TYPE_VOID;
        } else {
            gen_op("SUB");
            $$ = TYPE_INT;
        }
    }
  | expression '*' expression {
        if ($1 != TYPE_INT || $3 != TYPE_INT) {
            printf("Erro semântico (linha %d): Operação '*' requer inteiros.\n", yylineno);
            semantic_set_error();
            $$ = TYPE_VOID;
        } else {
            gen_op("MUL");
            $$ = TYPE_INT;
        }
    }
  | expression '/' expression {
        if ($1 != TYPE_INT || $3 != TYPE_INT) {
            printf("Erro semântico (linha %d): Operação '/' requer inteiros.\n", yylineno);
            semantic_set_error();
            $$ = TYPE_VOID;
        } else {
            gen_op("DIV");
            $$ = TYPE_INT;
        }
    }
  | NUM { gen_num($1); $$ = TYPE_INT; }
  | IDENTIFIER {
        if (semantic_check_var($1, yylineno)) {
            int idx = find_symbol($1);
            gen_id(symbol_table[idx].address);
            $$ = symbol_table[idx].type;
        } else {
            $$ = TYPE_VOID;
        }
    }
;

%%

void yyerror(const char *s)
{
	fprintf(stderr, "Erro de sintaxe: %s\n", s);
	result = 1;
}

int main(int argc, char **argv)
{
    extern FILE *yyin;
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            perror("fopen");
            return 1;
        }
    } else {
        yyin = stdin;
    }
    
    codegen_init("output.tm");
    semantic_init();

    if (yyparse() == 0 && result == 0 && !semantic_had_error()) 
    {
        printf("\nSintatico e semantico OK\n");
    } else 
    {
        printf("\nErro sintatico ou semantico.\n");
    }

    codegen_finalize();

    if (yyin != stdin) fclose(yyin);
    return result;
}
