%{
(****************************************************************************)
(*                           the diy toolsuite                              *)
(*                                                                          *)
(* Jade Alglave, University College London, UK.                             *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                          *)
(*                                                                          *)
(* Copyright 2015-present Institut National de Recherche en Informatique et *)
(* en Automatique and the authors. All rights reserved.                     *)
(*                                                                          *)
(* This software is governed by the CeCILL-B license under French law and   *)
(* abiding by the rules of distribution of free software. You can use,      *)
(* modify and/ or redistribute the software under the terms of the CeCILL-B *)
(* license as circulated by CEA, CNRS and INRIA at the following URL        *)
(* "http://www.cecill.info". We also give a copy in LICENSE.txt.            *)
(****************************************************************************)

open Ast

%}

%token EOF
%token <string> IDENTIFIER
%token <string> TYPEDEF_NAME (* TODO: lexer hack *)
%token <int> INT_LIT
%token <float> FLOAT_LIT
%token <char> CHAR_LIT
%token <string> STRING

%token LPAR RPAR LBRACE RBRACE LBRACK RBRACK
%token COMMA COLON DOT DOTS ARROW QUESTION
%token CHAR INT SHORT LONG FLOAT DOUBLE VOID SIGNED UNSIGNED
%token AUTO REGISTER STATIC EXTERN TYPEDEF
%token CONST VOLATILE
%token STRUCT UNION ENUM
%token DO FOR WHILE IF ELSE
%token SWITCH CASE DEFAULT GOTO BREAK CONTINUE RETURN
%token SIZEOF
%token SEMI

%token EQ STAR_EQ DIV_EQ MOD_EQ ADD_EQ SUB_EQ SHL_EQ SHR_EQ AND_EQ XOR_EQ PIPE_EQ
%token LAND LOR LNOT
%token EQ_OP NEQ_OP
%token LT LE GT GE

%token XOR PIPE AND SHR SHL NOT
%token ADDADD SUBSUB

%token ADD SUB
%token STAR DIV MOD

%token LIT_EXISTS LIT_AND LIT_OR

%type <Ast.Translation_unit.t> translation_unit
%start translation_unit

%type <Ast.Litmus.Test.t> litmus
%start litmus

%%

%inline clist(x):
  | xs = separated_list(COMMA, x) { xs }

%inline nclist(x):
  | xs = separated_nonempty_list(COMMA, x) { xs }

%inline slist(x):
  | xs = separated_list(SEMI, x) { xs }

%inline nslist(x):
  | xs = separated_nonempty_list(SEMI, x) { xs }

%inline braced(x):
  | xs = delimited(LBRACE, x, RBRACE) { xs }

%inline bracketed(x):
  | xs = delimited(LBRACK, x, RBRACK) { xs }

%inline parened(x):
  | xs = delimited(LPAR, x, RPAR) { xs }

%inline endsemi(x):
  | xs = terminated(x, SEMI) { xs }

litmus:
  | language = IDENTIFIER; name = IDENTIFIER; decls = litmus_declaration+; EOF
    { { Litmus.Test.language; name; decls } }

litmus_declaration:
  | decl = external_declaration { decl :> Litmus.Decl.t }
  | decl = litmus_initialiser   { `Init decl }
  | post = litmus_postcondition { `Post post }

litmus_initialiser:
  | xs = braced(list(endsemi(assignment_expression))) { xs }

litmus_quantifier:
  | LIT_EXISTS { `Exists }

litmus_postcondition:
  | quantifier = litmus_quantifier; predicate = parened(litmus_disjunct)
    { { Litmus.Post.quantifier; predicate } }

litmus_disjunct:
  | e = litmus_conjunct { e }
  | l = litmus_disjunct; LIT_OR; r = litmus_conjunct { Litmus.Pred.Or (l, r) }

litmus_conjunct:
  | e = litmus_equality { e }
  | l = litmus_conjunct; LIT_AND; r = litmus_equality { Litmus.Pred.And (l, r) }

litmus_equality:
  | e = parened(litmus_disjunct) { Litmus.Pred.Bracket (e) }
  | l = litmus_identifier; EQ_OP; r = constant { Litmus.Pred.Eq (l, r) }

litmus_identifier:
  | i = IDENTIFIER                     { Litmus.Id.Global (i) }
  | t = INT_LIT; COLON; i = IDENTIFIER { Litmus.Id.Local (t, i) }

translation_unit:
  | decls = external_declaration+ EOF { decls }

external_declaration:
  | func = function_definition { `Fun  func }
  | decl = declaration         { `Decl decl }

function_definition:
  | decl_specs = declaration_specifier*; signature = declarator; decls = declaration*; body = compound_statement
    { { Function_def.decl_specs; signature; decls; body } }

declaration:
  | qualifiers = declaration_specifier+; declarator = endsemi(clist(init_declarator))
    { { Decl.qualifiers; declarator } }

declaration_specifier:
  | spec = storage_class_specifier { spec :> [ Storage_class_spec.t | Type_spec.t | Type_qual.t ] }
  | spec = type_specifier          { spec :> [ Storage_class_spec.t | Type_spec.t | Type_qual.t ] }
  | qual = type_qualifier          { qual :> [ Storage_class_spec.t | Type_spec.t | Type_qual.t ] }

storage_class_specifier:
  | AUTO     { `Auto }
  | REGISTER { `Register }
  | STATIC   { `Static }
  | EXTERN   { `Extern }
  | TYPEDEF  { `Typedef }

type_specifier:
  | VOID                          { `Void }
  | CHAR                          { `Char }
  | SHORT                         { `Short }
  | INT                           { `Int }
  | LONG                          { `Long }
  | FLOAT                         { `Float }
  | DOUBLE                        { `Double }
  | SIGNED                        { `Signed }
  | UNSIGNED                      { `Unsigned }
  | s = struct_or_union_specifier { `Struct_or_union s }
  | e = enum_specifier            { `Enum e }
  | t = TYPEDEF_NAME              { `Defined_type t }

type_qualifier:
  | CONST    { `Const }
  | VOLATILE { `Volatile }

struct_or_union_specifier:
  | ty = struct_or_union; name_opt = identifier?; decls = braced(struct_declaration+)
    { Struct_or_union_spec.Literal { ty; name_opt; decls } }
  | ty = struct_or_union; name = identifier
    { Struct_or_union_spec.Named ( ty, name ) }

struct_or_union:
  | STRUCT { `Struct }
  | UNION  { `Union }

init_declarator:
  | declarator = declarator; initialiser = option(preceded(EQ, initialiser))
    { { Init_declarator.declarator; initialiser } }

struct_declaration:
  | qualifiers = specifier_qualifier+; declarator = endsemi(nclist(struct_declarator))
    { { Struct_decl.qualifiers; declarator } }

specifier_qualifier:
  | spec = type_specifier { spec :> [ Type_spec.t | Type_qual.t ] }
  | qual = type_qualifier { qual :> [ Type_spec.t | Type_qual.t ] }

struct_declarator:
  | decl = declarator
    { Struct_declarator.Regular decl }
  | decl = declarator?; COLON; length = expression
    { Struct_declarator.Bitfield (decl, length) }

enum_specifier:
  | ENUM; name_opt = identifier?; decls = braced(clist(enumerator))
    { Enum_spec.Literal { ty = `Enum; name_opt; decls } }
  | ENUM; name = identifier
    { Enum_spec.Literal { ty = `Enum; name_opt = Some name; decls = [] } }

enumerator:
  | name = identifier; value = option(preceded(EQ, constant_expression))
    { { Enumerator.name; value } }

declarator:
  | pointer = pointer?; direct = direct_declarator
    { { Declarator.pointer; direct } }

direct_declarator:
  | id = identifier
    { Direct_declarator.Id id }
  | d = parened(declarator)
    { Direct_declarator.Bracket d }
  | lhs = direct_declarator; index = bracketed(constant_expression?)
    { Direct_declarator.Array (lhs, index) }
  | lhs = direct_declarator; pars = parened(parameter_type_list)
    { Direct_declarator.Fun_decl (lhs, pars) }
  | lhs = direct_declarator; pars = parened(clist(identifier))
    { Direct_declarator.Fun_call (lhs, pars) }

pointer:
  | xs = nonempty_list(preceded(STAR, type_qualifier*)) { xs }

parameter_type_list:
  | params = nclist(parameter_declaration); variadic = boption(preceded(COMMA, DOTS))
    { { Param_type_list.params
      ; style = if variadic then `Variadic else `Normal
      } }

parameter_declarator:
  | d = declarator           { `Concrete d }
  | d = abstract_declarator? { `Abstract d }

parameter_declaration:
  | qualifiers = declaration_specifier+; declarator = parameter_declarator
    { { Param_decl.qualifiers; declarator } }

initialiser:
  | expr = assignment_expression { Initialiser.Assign expr }
  | xs = braced(terminated(nclist(initialiser), COMMA?))
    { Initialiser.List xs }

type_name:
  | qualifiers = specifier_qualifier+; declarator = abstract_declarator?
    { { Type_name.qualifiers; declarator } }

abstract_declarator:
  | pointer = pointer
    { Abs_declarator.Pointer pointer }
  | pointer = pointer?; direct = direct_abstract_declarator
    { Abs_declarator.Direct (pointer, direct) }

direct_abstract_declarator:
  | d = parened(abstract_declarator)
    { Direct_abs_declarator.Bracket d }
  | lhs = direct_abstract_declarator?; index = bracketed(constant_expression?)
    { Direct_abs_declarator.Array (lhs, index) }
  | lhs = direct_abstract_declarator?; pars = parened(parameter_type_list?)
    { Direct_abs_declarator.Fun_decl (lhs, pars) }

statement:
  | s = labelled_statement   { s }
  | s = expression_statement { s }
  | s = compound_statement   { Stm.Compound s }
  | s = selection_statement  { s }
  | s = iteration_statement  { s }
  | s = jump_statement       { s }

labelled_statement:
  | id = identifier; COLON; s = statement { Stm.Label (Label.Normal id, s) }
  | CASE; cond = constant_expression; s = statement { Stm.Label (Label.Case cond, s) }
  | DEFAULT; COLON; s = statement { Stm.Label (Label.Default, s) }

expression_statement:
  | e = endsemi(expression?) { Stm.Expr e }

compound_statement:
  | LBRACE; decls = declaration*; stms = statement*; RBRACE
    { { Compound_stm.decls; stms } }

selection_statement:
  | IF; cond = parened(expression); t_branch = statement; f_branch = option(preceded(ELSE, statement))
    { Stm.If { cond; t_branch; f_branch } }
  | SWITCH; cond = parened(expression); body = statement
    { Stm.Switch (cond, body) }

iteration_statement:
  | WHILE; cond = parened(expression); body = statement
    { Stm.While (cond, body) }
  | DO; body = statement; WHILE; cond = parened(expression)
    { Stm.Do_while (body, cond) }
  | FOR LPAR; init = expression?; SEMI; cond = expression?; SEMI; update = expression?; RPAR; body = statement
    { Stm.For { init; cond; update; body } }

jump_statement:
  | GOTO; id = identifier { Stm.Goto id }
  | CONTINUE { Stm.Continue }
  | BREAK { Stm.Break }
  | RETURN; ret = expression? { Stm.Return ret }

expression:
  | e = assignment_expression { e }
  | l = expression; COMMA; r = assignment_expression
    { Expr.Binary (l, `Comma, r) }

assignment_expression:
  | e = conditional_expression { e }
  | l = unary_expression; o = assignment_operator; r = assignment_expression
    { Expr.Binary (l, o, r) }

assignment_operator:
  | EQ      { `Assign }
  | STAR_EQ { `Assign_mul }
  | DIV_EQ  { `Assign_div }
  | MOD_EQ  { `Assign_mod }
  | ADD_EQ  { `Assign_add }
  | SUB_EQ  { `Assign_sub }
  | SHL_EQ  { `Assign_shl }
  | SHR_EQ  { `Assign_shr }
  | AND_EQ  { `Assign_and }
  | XOR_EQ  { `Assign_xor }
  | PIPE_EQ { `Assign_or }

conditional_expression:
  | e = logical_or_expression { e }
  | cond = logical_or_expression; QUESTION; t_expr = expression; COLON; f_expr = expression
    { Expr.Ternary { cond; t_expr; f_expr } }

constant_expression:
  | e = conditional_expression { e }

logical_or_expression:
  | e = logical_and_expression { e }
  | l = logical_or_expression; LOR; r = logical_and_expression
    { Expr.Binary (l, `Lor, r) }

logical_and_expression:
  | e = inclusive_or_expression { e }
  | l = logical_and_expression; LAND; r = inclusive_or_expression
    { Expr.Binary (l, `Land, r) }

inclusive_or_expression:
  | e = exclusive_or_expression { e }
  | l = inclusive_or_expression; PIPE; r = exclusive_or_expression
    { Expr.Binary (l, `Or, r) }

exclusive_or_expression:
  | e = and_expression { e }
  | l = exclusive_or_expression; XOR; r = and_expression
    { Expr.Binary (l, `Xor, r) }

and_expression:
  | e = equality_expression { e }
  | l = and_expression; AND; r = equality_expression
    { Expr.Binary (l, `And, r) }

equality_op:
  | EQ_OP  { `Eq } (* == *)
  | NEQ_OP { `Ne } (* != *)

equality_expression:
  | e = relational_expression { e }
  | l = equality_expression; o = equality_op; r = relational_expression
    { Expr.Binary (l, o, r) }

relational_op:
  | LT { `Lt } (* < *)
  | LE { `Le } (* <= *)
  | GE { `Ge } (* >= *)
  | GT { `Gt } (* > *)

relational_expression:
  | e = shift_expression { e }
  | l = relational_expression; o = relational_op; r = shift_expression
    { Expr.Binary (l, o, r) }

shift_op:
  | SHL { `Shl } (* << *)
  | SHR { `Shr } (* >> *)

shift_expression:
  | e = additive_expression { e }
  | l = shift_expression; o = shift_op; r = additive_expression
    { Expr.Binary (l, o, r) }

additive_op:
  | ADD { `Add } (* + *)
  | SUB { `Sub } (* - *)

additive_expression:
  | e = multiplicative_expression { e }
  | l = additive_expression; o = additive_op; r = multiplicative_expression
    { Expr.Binary (l, o, r) }

multiplicative_op:
  | STAR { `Mul } (* * *)
  | DIV  { `Div } (* / *)
  | MOD  { `Mod } (* % *)

multiplicative_expression:
  | e = cast_expression { e }
  | l = multiplicative_expression; o = multiplicative_op; r = cast_expression
    { Expr.Binary (l, o, r) }

cast_expression:
  | e = unary_expression { e }
  | ty = parened(type_name); e = cast_expression { Expr.Cast (ty, e) }

inc_or_dec_operator:
  | ADDADD { `Inc } (* ++ *)
  | SUBSUB { `Dec } (* -- *)

unary_operator_unary:
  | o = inc_or_dec_operator { o :> Operator.pre }
  | SIZEOF { `Sizeof_val }

unary_operator_cast:
  | AND  { `Ref }
  | STAR { `Deref }
  | ADD  { `Add }
  | SUB  { `Sub }
  | NOT  { `Not }
  | LNOT { `Lnot }

unary_expression:
  | e = postfix_expression { e }
  | o = unary_operator_unary; e = unary_expression { Expr.Prefix (o, e) }
  | o = unary_operator_cast; e = cast_expression { Expr.Prefix ((o :> Operator.pre), e) }
  | SIZEOF; ty = parened(type_name) { Expr.Sizeof_type (ty) }

field_access:
  | DOT   { `Direct } (* . *)
  | ARROW { `Deref }  (* -> *)

postfix_expression:
  | e = primary_expression { e }
  | array = postfix_expression; index = expression
    { Expr.Subscript { array; index } }
  | func = postfix_expression; arguments = parened(argument_expression_list)
    { Expr.Call { func; arguments } }
  | value = postfix_expression; access = field_access; field = identifier
    { Expr.Field { value; field; access } }
  | e = postfix_expression; o = inc_or_dec_operator
    { Expr.Postfix (e, o) }

(* We can't use clist here; it produces a reduce-reduce conflict. *)
argument_expression_list:
  | x = assignment_expression { [x] }
  | x = assignment_expression; COMMA; xs = argument_expression_list { x::xs }

primary_expression:
  | i = identifier          { Expr.Identifier i }
  | k = constant            { Expr.Constant   k }
  | s = STRING              { Expr.String     s }
  | e = parened(expression) { Expr.Brackets   e }

constant:
  | i = INT_LIT   { Constant.Integer i }
  | c = CHAR_LIT  { Constant.Char    c }
  | f = FLOAT_LIT { Constant.Float   f }

identifier:
  | i = IDENTIFIER { i }
(* Contextual keywords. *)
  | LIT_EXISTS { "exists" }
