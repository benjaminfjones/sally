/*
 * term_manager.h
 *
 *  Created on: Nov 17, 2014
 *      Author: dejan
 */

#pragma once

#include "expr/term.h"

namespace sal2 {
namespace expr {

class term_manager_internal;

class term_manager {

  /** Internal term manager implementation */
  term_manager_internal* d_tm;

  friend class set_tm;

public:

  /** Construct them manager */
  term_manager(bool typecheck);

  /** Destruct the manager, and destruct all payloads that the manager owns */
  ~term_manager();

  /** Get the internal term manager */
  term_manager_internal* get_internal() { return d_tm; }

  /** Print the term manager information and all the terms to out */
  void to_stream(std::ostream& out) const;

  /** Get the Boolean type */
  term_ref booleanType() const;

  /** Get the Integer type */
  term_ref integerType() const;

  /** Get the Real type */
  term_ref realType() const;

  /** Make a term, given children */
  term_ref mk_term(term_op op, term_ref c);

  /** Make a term, given children */
  term_ref mk_term(term_op op, term_ref c1, term_ref c2);

  /** Make a term, given children */
  term_ref mk_term(term_op op, const std::vector<term_ref>& children);

  /** Make a term, given children */
  term_ref mk_term(term_op op, const term_ref* children_begin, const term_ref* children_end);

  /** Make a term, given children */
  term_ref mk_term(term_op op, const term_ref* children, size_t n) {
    return mk_term(op, children, children + n);
  }

  /** Make a new variable */
  term_ref mk_variable(std::string name, term_ref type);

  /** Get the name of this variable */
  std::string get_variable_name(const term& t) const;

  /** Get the type of this variable */
  term_ref get_variable_type(const term& t) const;

  /** Make a new boolean constant */
  term_ref mk_boolean_constant(bool value);

  /** Returns the boolan constant value */
  bool get_boolean_constant(const term& t) const;

  /** Make a new rational constant */
  term_ref mk_rational_constant(const rational& value);

  /** Returns the rational constant value */
  rational get_rational_constant(const term& t) const;

  /** Make a new string constant */
  term_ref mk_string_constant(std::string value);

  /** Returns the string constant value */
  std::string get_string_constant(const term& t) const;

  /** Get a reference for the term */
  term_ref ref_of(const term& term) const;

  /** Get a term of the reference */
  const term& term_of(term_ref ref) const;

  /** Get the number of children this term has. */
  size_t term_size(const term& t) const;

  /** First child */
  const term_ref* term_begin(const term& t) const;

  /** End of children (one past) */
  const term_ref* term_end(const term& t) const;

  /** Get the type of the term */
  term_ref type_of(const term& t) const;

  /** Get the type of the term */
  term_ref type_of(term_ref t) const {
    return type_of(term_of(t));
  }

  /** Get the TCC of the term */
  term_ref tcc_of(const term& t) const;

  /** Get the TCC of the term */
  term_ref tcc_of(const term_ref& t) const {
    return tcc_of(term_of(t));
  }

  /** Get the id of the term */
  size_t id_of(term_ref ref) const;

  /** Get the hash of the term */
  size_t hash_of(term_ref ref) const {
    if (ref.is_null()) return 0;
    return term_of(ref).hash();
  }

  /** Get the string representation of the term */
  std::string to_string(term_ref ref) const;
};

inline
std::ostream& operator << (std::ostream& out, const term_manager& tm) {
  tm.to_stream(out);
  return out;
}

/** IO modifier to set the term manager */
struct set_tm {
  const term_manager_internal* d_tm;
  set_tm(const term_manager_internal& tm): d_tm(&tm) {}
  set_tm(const term_manager& tm): d_tm(tm.d_tm) {}
};

/** IO manipulator to set the term manager on the stream */
std::ostream& operator << (std::ostream& out, const set_tm& stm);

}
}
