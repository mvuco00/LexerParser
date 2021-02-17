/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

int comment = 0;
int string_length = 0;


/*
 *  Add Your own definitions here
 */

bool stringTooLong(int);
int stringTooLongError();
void ResetStr();
%}

/*
 * Define names for regular expressions here.
 */

BROJ		[0-9]
TYPE 		[A-Z]([a-zA-Z_]|{BROJ})*
OBJEKT		[a-z]([a-zA-Z_]|{BROJ})*

DARROW 		"=>"
LE		"<="
ASSIGN		"<-"

ZNAKOVI		"("|")"|":"|"."|"@"|"~"|","|"{"|"}"|";"|"+"|"-"|"*"|"/"|"<"|"="
OTHER		"#"|"$"|"%"|"^"|"&"|"?"|"!"|">"|"_"|"`"|"["|"]"|"|"|"\\"

%x STRING
%x STRING_ERROR
%x COMMENT
%x DASH_COMMENT
%%

 /*
  *  Komentari
  */

"--"	{BEGIN(DASH_COMMENT);}

<DASH_COMMENT>{
	.	{}
	\n	{curr_lineno++; BEGIN(INITIAL);}
}


"(*" {
	comment++;
	BEGIN(COMMENT);
}

<COMMENT>{
	"(*"	{ comment++; }

	.|[ \f\b\t\r]+ {}

	"*)"	{ comment--;
		if(comment==0){
		BEGIN(INITIAL); }}

	\n	{curr_lineno++;}


	<<EOF>> { yylval.error_msg = "EOF in comment";
		BEGIN(INITIAL);
		return (ERROR); }
}

"*)" { yylval.error_msg = "Unmatched *)";
	return (ERROR);
}

 /*
  *  Case-insesitive, true, false, znakovi
  */

{DARROW}	return DARROW;
{ASSIGN}	return ASSIGN;
{LE}		return LE;

[Cc][Ll][Aa][Ss][Ss]    { return (CLASS); }
[Ee][Ll][Ss][Ee]        { return (ELSE);  }
[Ii][Ff]                { return (IF);    }
[Tt][Hh][Ee][Nn]        { return (THEN); }
[Ww][Hh][Ii][Ll][Ee]    { return (WHILE); }
[Nn][Ee][Ww]            { return (NEW); }
[Ii][Nn]                { return (IN); }
[Ff][Ii]                { return (FI);    }
[Ll][Oo][Oo][Pp]        { return (LOOP); }
[Pp][Oo][Oo][Ll]        { return (POOL); }
[Cc][Aa][Ss][Ee]        { return (CASE); }
[Ee][Ss][Aa][Cc]        { return (ESAC); };
[Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss]    { return (INHERITS); }
[Ll][Ee][Tt]            { return (LET); }
[Ii][Ss][Vv][Oo][Ii][Dd]    { return (ISVOID); }
[Nn][Oo][Tt]            { return (NOT); }
[Oo][Ff]                { return (OF); }

{ZNAKOVI}	{return int(yytext[0]);}


[ \r\t\v\f]+	{ }
\n		{curr_lineno++;}

[f][Aa][Ll][Ss][Ee]	{ cool_yylval.boolean = false;
			return BOOL_CONST;}

[t][Rr][Uu][Ee]		{ cool_yylval.boolean = true;
			return BOOL_CONST;}


{BROJ}+		{ cool_yylval.symbol = inttable.add_string(yytext);
		return (INT_CONST); }

{TYPE}		{ cool_yylval.symbol = idtable.add_string(yytext);
		return TYPEID;}

{OBJEKT}	{ cool_yylval.symbol = idtable.add_string(yytext);
		return OBJECTID; }

{OTHER}		{ cool_yylval.error_msg = yytext; 
		return (ERROR); }
 /*
  *  Stringovi
  */

\"	{ BEGIN(STRING); }

<STRING>{

	\"	{ cool_yylval.symbol = stringtable.add_string(string_buf);
		ResetStr();
		BEGIN(INITIAL);
		return STR_CONST; }

	(\0|\\\0)	{ cool_yylval.error_msg = "String contains null character";
			BEGIN(STRING_ERROR);
			return(ERROR); }

	<<EOF>>		{ cool_yylval.error_msg = "EOF in string constant";
			BEGIN(INITIAL);
			return ERROR; }

	\n	{ curr_lineno++;
		cool_yylval.error_msg = "Unterminated string constant";
		ResetStr();
		BEGIN(INITIAL);
		return ERROR; }

	\\\n	{ if(stringTooLong(string_length+1)){ 
			return stringTooLongError();
			} else {
				string_length++;
				curr_lineno++;
				strcat(string_buf, "\n");
				} }

	\\[n|t|b|f]	{ if(stringTooLong(string_length+1)){ 
				return stringTooLongError();
				} else {
					string_length++;
					char *c = &yytext[1];
					if(*c=='n'){ strcat(string_buf, "\n"); } 
					else if(*c=='t'){ strcat(string_buf, "\t"); }
					else if(*c=='b'){ strcat(string_buf, "\b"); } 
					else if(*c=='f'){ strcat(string_buf, "\f"); }
				} }


	\\.	{ if(stringTooLong(string_length+1)){ 
			return stringTooLongError();
			} else {
				string_length++;
				strcat(string_buf, &strdup(yytext)[1]);
				} }

	.	{ if(stringTooLong(string_length+1)){ 
			return stringTooLongError();
			} else {
				string_length++;
				strcat(string_buf, yytext);
				} }
}

<STRING_ERROR>.*[\"|\n] { BEGIN(INITIAL); }

.	{
	cool_yylval.error_msg = yytext;
	return (ERROR);
	}
%%

 /*
  *  Funkcije
  */

bool stringTooLong(int strnum){
	if (strnum >= MAX_STR_CONST){
		return true;
	}
	return false;
}
int stringTooLongError() {
	BEGIN(STRING_ERROR);
	ResetStr();
	cool_yylval.error_msg = "String constant too long";
	return ERROR;
}

void ResetStr(){
	string_length = 0;
	string_buf[0] = '\0';
}