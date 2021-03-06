// Copyright 2014 Jonathan Graehl - http://graehl.org/
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#ifndef GRAEHL_SHARED__DEFAULTED_HPP
#define GRAEHL_SHARED__DEFAULTED_HPP

//C++ doesn't have default initilaized primitives. stupid.

#include <cstddef>


namespace graehl {
template <class V, unsigned long long default_val = 0>
struct defaulted {
  static const V default_value = default_val;
  typedef V value_type;
  V v;
  typedef V* iterator;
  typedef V const* const_iterator;
  iterator begin() {
    return &v;
  }
  iterator end() {
    return &v+1;
  }
  const_iterator begin() const {
    return &v;
  }
  const_iterator end() const {
    return &v+1;
  }
  operator V() const {
    return v;
  }
  defaulted() : v(default_value) {  }
  explicit defaulted(V const& v) : v(v) {  }
#define GRAEHL_DEFAULTED_OP(op) template <class W> V &operator op(W const& w) {  v op w; return v; }
#define GRAEHL_DEFAULTED_CONST_OP(op) template <class W> V operator op(W const& w) const {  return v op w; }
  GRAEHL_DEFAULTED_OP( = )
#if 0
  template <class O>
  friend inline operator<<(O &o, defaulted const& x) {
    return o<<x.v;
  }
  template <class O>
  friend inline operator>>(O &o, defaulted & x) {
    return o>>x.v;
  }
#endif
#undef GRAEHL_DEFAULTED_OP
#undef GRAEHL_DEFAULTED_CONST_OP
};
} //ns

#endif
