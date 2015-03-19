grammar mcmt;

options {
  // C output for antlr
  language = 'C';  
}
 
@parser::includes {
  #include <string>
  #include "parser/command.h"
  #include "parser/mcmt/mcmt_state.h"
  using namespace sally;
}

@parser::postinclude {
  #define STATE (ctx->pState)
}


@parser::context
{
  /** The sally part of the parser state */
  parser::mcmt_state* pState;
}

/** Parses a command */
command returns [parser::command* cmd = 0] 
  : internal_command* c = system_command { $cmd = c; }
  | internal_command* EOF { $cmd = 0; } 
  ;

/** Parser an internal command */
internal_command
  : define_constant
  ; 

/** Parses a system definition command */  
system_command returns [parser::command* cmd = 0] 
  : c = declare_state_type       { $cmd = c; }
  | c = define_states            { $cmd = c; }
  | c = define_transition        { $cmd = c; }
  | c = define_transition_system { $cmd = c; }
  | c = assume                   { $cmd = c; }                    
  | c = query                    { $cmd = c; }
  ;
  
/** Declaration of a state type */
declare_state_type returns [parser::command* cmd = 0]
@declarations {
  std::string id;
  std::vector<std::string> vars;  
  std::vector<expr::term_ref> types;
}
  : '(' 'define-state-type' 
        symbol[id, parser::MCMT_STATE_TYPE, false]  
        variable_list[vars, types] 
    ')' 
    {
      $cmd = new parser::declare_state_type_command(id, STATE->mk_state_type(id, vars, types));
    }
  ; 

/** Definition of a state set  */
define_states returns [parser::command* cmd = 0]
@declarations {
  std::string id;
  std::string type_id;
}
  : '(' 'define-states'
        symbol[id, parser::MCMT_STATE_FORMULA, false]       
        symbol[type_id, parser::MCMT_STATE_TYPE, true] { 
            STATE->push_scope(); 
            STATE->use_state_type(type_id, system::state_type::STATE_CURRENT, true); 
        }
        f = state_formula { 
        	$cmd = new parser::define_states_command(id, STATE->mk_state_formula(id, type_id, f)); 
            STATE->pop_scope(); 
        }
    ')'
  ; 

/** Definition of a transition  */
define_transition returns [parser::command* cmd = 0]
@declarations {
  std::string id;
  std::string type_id;  
}
  : '(' 'define-transition'
      symbol[id, parser::MCMT_TRANSITION_FORMULA, false]
      symbol[type_id, parser::MCMT_STATE_TYPE, true] { 
      	  STATE->push_scope();
          STATE->use_state_type(type_id, system::state_type::STATE_CURRENT, STATE->lsal_extensions()); 
          STATE->use_state_type(type_id, system::state_type::STATE_NEXT, false); 
      }
      f = state_transition_formula   { 
          $cmd = new parser::define_transition_command(id, STATE->mk_transition_formula(id, type_id, f)); 
          STATE->pop_scope(); 
      }
    ')'
  ; 

/** Definition of a transition system  */
define_transition_system returns [parser::command* cmd = 0]
@declarations {
  std::string id;
  std::string type_id;  
  std::string initial_id;
  std::vector<std::string> transitions;  
}
  : '(' 'define-transition-system'
      symbol[id, parser::MCMT_TRANSITION_SYSTEM, false]                    
      symbol[type_id, parser::MCMT_STATE_TYPE, true]
      symbol[initial_id, parser::MCMT_STATE_FORMULA, true]            
      transition_list[transitions]  {  
        $cmd = new parser::define_transition_system_command(id, STATE->mk_transition_system(id, type_id, initial_id, transitions));
      } 
    ')'
  ; 

/** A list of transitions */
transition_list[std::vector<std::string>& transitions] 
@declarations {
  std::string id;
} 
  : '(' (
    symbol[id, parser::MCMT_TRANSITION_FORMULA, true] { 
        transitions.push_back(id); 
    }
  	)+ ')'
  ;

/** Assumptions  */
assume returns [parser::command* cmd = 0]
@declarations {
  std::string id;
  system::state_type* state_type;
}
  : '(' 'assume'
    symbol[id, parser::MCMT_TRANSITION_SYSTEM, true] { 
        STATE->push_scope();
        state_type = STATE->ctx().get_transition_system(id)->get_state_type();
        STATE->use_state_type(state_type, system::state_type::STATE_CURRENT, true); 
    }
    f = state_formula { 
    	$cmd = new parser::assume_command(STATE->ctx(), id, new system::state_formula(STATE->tm(),  state_type, f));
        STATE->pop_scope(); 
    }
    ')'
  ; 
  
/** Query  */
query returns [parser::command* cmd = 0]
@declarations {
  std::string id;
  system::state_type* state_type;
}
  : '(' 'query'
    symbol[id, parser::MCMT_TRANSITION_SYSTEM, true] { 
        STATE->push_scope();
        state_type = STATE->ctx().get_transition_system(id)->get_state_type();
        STATE->use_state_type(state_type, system::state_type::STATE_CURRENT, true); 
    }
    f = state_formula { 
    	$cmd = new parser::query_command(STATE->ctx(), id, new system::state_formula(STATE->tm(), state_type, f));
        STATE->pop_scope(); 
    }
    ')'
  ; 

/** Parse a constant definition */
define_constant 
@declarations {
  std::string id;
}
  : '(' 'define-constant'
    symbol[id, parser::MCMT_VARIABLE, false] 
    c = constant { STATE->set_variable(id, c); }
    ')'
  ; 

/** A state formula */
state_formula returns [expr::term_ref sf = expr::term_ref()]
  : t = term { $sf = t; }
  ;

/** A state transition formula */
state_transition_formula returns [expr::term_ref stf = expr::term_ref()]
  : t = term { $stf = t; }
  ;

/** SMT2 term */
term returns [expr::term_ref t = expr::term_ref()]
@declarations{
  std::string id;
  std::vector<expr::term_ref> children;
} 
  : symbol[id, parser::MCMT_VARIABLE, true] { t = STATE->get_variable(id); }                
  | c = constant { t = c; }
  | '(' 'let'
       { STATE->push_scope(); } 
       let_assignments 
       let_t = term { t = let_t; }
       { STATE->pop_scope(); }
    ')' 
  | '(' 
        op = term_op 
        term_list[children] 
     ')'   
     { t = STATE->tm().mk_term(op, children); }
  | '(' 'cond' { STATE->lsal_extensions() }?
       ( '(' term_list[children] ')' )+
       '(' 'else' else_term = term ')'
       { 
       	 children.push_back(else_term);
       	 t = STATE->mk_cond(children);
       }
    ')'
  | '(' '/=' { STATE->lsal_extensions() }? term_list[children] 
    {
  	  t = STATE->tm().mk_term(expr::TERM_EQ, children);
  	  t = STATE->tm().mk_term(expr::TERM_NOT, t);
    }   
    ')'
  ; 
  
let_assignments 
  : '(' let_assignment+ ')'
  ; 
  
let_assignment 
@declarations {
  std::string id;
}
  : '(' symbol[id, parser::MCMT_VARIABLE, false] 
        t = term 
        { STATE->set_variable(id, t); }
    ')'
  ;  
  
/** 
 * A symbol. Returns it in the id string. If obj_type is not MCMT_OBJECT_LAST
 * we check whether it has been declared = true/false.
 */
symbol[std::string& id, parser::mcmt_object obj_type, bool declared] 
@declarations {
  bool is_next = false;
}
  : SYMBOL ('\'' { STATE->lsal_extensions() }? { is_next = true; })? { 
  	    id = STATE->token_text($SYMBOL);
        if (is_next) { id = "next." + id; }
        STATE->ensure_declared(id, obj_type, declared);
    }
  ;
    
term_list[std::vector<expr::term_ref>& out]
  : ( t = term { out.push_back(t); } )+
  ;
  
constant returns [expr::term_ref t = expr::term_ref()] 
  : bc = bool_constant     { t = bc; } 
  | dc = decimal_constant  { t = dc; } 
  ; 

bool_constant returns [expr::term_ref t = expr::term_ref()]
  : 'true'   { t = STATE->tm().mk_boolean_constant(true); }
  | 'false'  { t = STATE->tm().mk_boolean_constant(false); }
  ;
  
decimal_constant returns [expr::term_ref t = expr::term_ref()]
  : NUMERAL { 
     expr::integer value(STATE->token_text($NUMERAL), 10);
     t = STATE->tm().mk_integer_constant(value);
    }
  ; 

term_op returns [expr::term_op op = expr::OP_LAST]
  : 'and'            { op = expr::TERM_AND; } 
  | 'or'             { op = expr::TERM_OR; }
  | 'not'            { op = expr::TERM_NOT; }
  | 'implies'        { op = expr::TERM_IMPLIES; } 
  | 'xor'            { op = expr::TERM_XOR; }
  | 'ite'            { op = expr::TERM_ITE; }
  | '='              { op = expr::TERM_EQ;  }
  | '+'              { op = expr::TERM_ADD; }
  | '-'              { op = expr::TERM_SUB; }
  | '*'              { op = expr::TERM_MUL; }
  | '/'              { op = expr::TERM_DIV; }
  | '>'              { op = expr::TERM_GT; }
  | '>='             { op = expr::TERM_GEQ; }
  | '<'              { op = expr::TERM_LT; }
  | '<='             { op = expr::TERM_LEQ; }
  ;

/** Parse a list of variables with types */
variable_list[std::vector<std::string>& out_vars, std::vector<expr::term_ref>& out_types]
@declarations {
  std::string var_id;
  std::string type_id;
} 
  : '(' 
    ( '(' 
        symbol[var_id, parser::MCMT_OBJECT_LAST, false] { 
        	out_vars.push_back(var_id); 
        } 
        symbol[type_id, parser::MCMT_TYPE, true] { 
        	out_types.push_back(STATE->get_type(type_id)); 
        }
    ')' )+ 
    ')'
  ; 
        
/** Comments (skip) */
COMMENT
  : ';' (~('\n' | '\r'))* { SKIP(); }
  ; 
  
/** Whitespace (skip) */
WHITESPACE
  : (' ' | '\t' | '\f' | '\r' | '\n')+ { SKIP(); }
  ;
  
/** Matches a symbol. */
SYMBOL
  : ALPHA (ALPHA | DIGIT | '_' | '@' | '.' | '!' )*
  ;

/** Matches a letter. */
fragment
ALPHA : 'a'..'z' | 'A'..'Z';

/** Matches a numeral (sequence of digits) */
NUMERAL: DIGIT+;

/** Matches a digit */
fragment 
DIGIT : '0'..'9';  
 
