//===-- llvm/FMF.h - Fast math flags subclass -------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the fast math flags.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_IR_FMF_H
#define LLVM_IR_FMF_H

#include "llvm/Support/Compiler.h"

namespace llvm {
class raw_ostream;

/// Convenience struct for specifying and reasoning about fast-math flags.
class FastMathFlags {
private:
  friend class FPMathOperator;

  unsigned Flags = 0;

  FastMathFlags(unsigned F) : Flags(F) {}

public:
  // This is how the bits are used in Value::SubclassOptionalData so they
  // should fit there too.
  // WARNING: We're out of space. SubclassOptionalData only has 7 bits. New
  // functionality will require a change in how this information is stored.
  enum {
    AllowReassoc    = (1 << 0),
    NoNaNs          = (1 << 1),
    NoInfs          = (1 << 2),
    NoSignedZeros   = (1 << 3),
    AllowReciprocal = (1 << 4),
    AllowContract   = (1 << 5),
    ApproxFunc      = (1 << 6),
    FlagEnd         = (1 << 7)
  };

  constexpr static unsigned AllFlagsMask = FlagEnd - 1;

  FastMathFlags() = default;

  static FastMathFlags getFast() {
    FastMathFlags FMF;
    FMF.setFast();
    return FMF;
  }

  bool any() const { return Flags != 0; }
  bool none() const { return Flags == 0; }
  bool all() const { return Flags == AllFlagsMask; }

  void clear() { Flags = 0; }
  void set() { Flags = AllFlagsMask; }

  /// Flag queries
  bool allowReassoc() const    { return 0 != (Flags & AllowReassoc); }
  bool noNaNs() const          { return 0 != (Flags & NoNaNs); }
  bool noInfs() const          { return 0 != (Flags & NoInfs); }
  bool noSignedZeros() const   { return 0 != (Flags & NoSignedZeros); }
  bool allowReciprocal() const { return 0 != (Flags & AllowReciprocal); }
  bool allowContract() const   { return 0 != (Flags & AllowContract); }
  bool approxFunc() const      { return 0 != (Flags & ApproxFunc); }
  /// 'Fast' means all bits are set.
  bool isFast() const          { return all(); }

  /// Flag setters
  void setAllowReassoc(bool B = true) {
    Flags = (Flags & ~AllowReassoc) | B * AllowReassoc;
  }
  void setNoNaNs(bool B = true) {
    Flags = (Flags & ~NoNaNs) | B * NoNaNs;
  }
  void setNoInfs(bool B = true) {
    Flags = (Flags & ~NoInfs) | B * NoInfs;
  }
  void setNoSignedZeros(bool B = true) {
    Flags = (Flags & ~NoSignedZeros) | B * NoSignedZeros;
  }
  void setAllowReciprocal(bool B = true) {
    Flags = (Flags & ~AllowReciprocal) | B * AllowReciprocal;
  }
  void setAllowContract(bool B = true) {
    Flags = (Flags & ~AllowContract) | B * AllowContract;
  }
  void setApproxFunc(bool B = true) {
    Flags = (Flags & ~ApproxFunc) | B * ApproxFunc;
  }
  void setFast(bool B = true) { B ? set() : clear(); }

  void operator&=(const FastMathFlags &OtherFlags) {
    Flags &= OtherFlags.Flags;
  }
  void operator|=(const FastMathFlags &OtherFlags) {
    Flags |= OtherFlags.Flags;
  }
  bool operator!=(const FastMathFlags &OtherFlags) const {
    return Flags != OtherFlags.Flags;
  }

  /// Print fast-math flags to \p O.
  LLVM_ABI void print(raw_ostream &O) const;

  /// Intersect rewrite-based flags
  static inline FastMathFlags intersectRewrite(FastMathFlags LHS,
                                               FastMathFlags RHS) {
    const unsigned RewriteMask =
        AllowReassoc | AllowReciprocal | AllowContract | ApproxFunc;
    return FastMathFlags(RewriteMask & LHS.Flags & RHS.Flags);
  }

  /// Union value flags
  static inline FastMathFlags unionValue(FastMathFlags LHS, FastMathFlags RHS) {
    const unsigned ValueMask = NoNaNs | NoInfs | NoSignedZeros;
    return FastMathFlags(ValueMask & (LHS.Flags | RHS.Flags));
  }
};

inline FastMathFlags operator|(FastMathFlags LHS, FastMathFlags RHS) {
  LHS |= RHS;
  return LHS;
}

inline FastMathFlags operator&(FastMathFlags LHS, FastMathFlags RHS) {
  LHS &= RHS;
  return LHS;
}

inline raw_ostream &operator<<(raw_ostream &O, FastMathFlags FMF) {
  FMF.print(O);
  return O;
}

} // end namespace llvm

#endif // LLVM_IR_FMF_H
