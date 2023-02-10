%{
#include "y.tab.h"
#include <string.h>
%}

%%

[0-9]+ {
	yylval.ivalue=atoi(yytext);
    return VALUE_INTEGER;
}

[A-Z|a-z|0-9|\_|\,]+ {
	yylval.svalue=yytext;
	return STRING;
}

Query:(\/?\/?[a-zA-Z]+)+ {
	yylval.svalue=yytext;
	return QUERY;
}

[\@\[\]\/|\<|\>|\n\=\ ]	return *yytext;

[ \t]  return TAB;

.		yyerror("Unknown character");
