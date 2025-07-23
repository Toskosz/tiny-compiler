%{
#include <stdio.h>
#include "simple.tab.h"
#include <string.h>
%}
digit [0-9]
number ([-+]?[1-9]{digit}*)|{digit}
id	[a-z][a-z0-9]*
whitespace [ \t]+

%x comment

%%
"/*"          {BEGIN(comment);}
<comment>"*/" {BEGIN(INITIAL);}
<comment>\n   {yylineno++;}
<comment>.    {}

":="      {return ASSGNOP;}
"<"   { yylval.sval = strdup(yytext); return LT; }
">"   { yylval.sval = strdup(yytext); return GT; }
"="   { yylval.sval = strdup(yytext); return EQ; }
"<>"  { yylval.sval = strdup(yytext); return NEQ; }
"&&"  { yylval.sval = strdup(yytext); return AND_OP; }
"||"  { yylval.sval = strdup(yytext); return OR_OP; }
"+"       { return '+'; }
"-"       { return '-'; }
"*"       { return '*'; }
"/"       { return '/'; }
"^"       { return '^'; }
"("       { return '('; }
")"       { return ')'; }
";"       { return ';'; } /* For statement termination */
do        {return DO;}
else      {return ELSE;}
end       {return END;}
fi        {return FI;}
if        {return IF;}
in        {return IN;}
integer   {return INTEGER;}
let       {return LET;}
print     {return PRINT;}
read      {return READ;}
skip      {return SKIP;}
then      {return THEN;}
while     {return WHILE;}
write     {return WRITE;}

{number}     { yylval.ival = atoi(yytext); return NUM; } /* Good practice to use atoi */ 
{id}         { yylval.sval = strdup(yytext); return IDENTIFIER; }
{whitespace} { ; }
\r            { ; } /* Ignore carriage returns */
\n           { yylineno++; }
.            { fprintf(stderr, "Lexical Error (linha %d): Caractere inesperado '%s'\n", yylineno, yytext); }
%%
int yywrap() {
  return 1;
}
