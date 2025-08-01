//===--- InvalidEnumDefaultInitializationCheck.h - clang-tidy -*- C++ -*---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_CLANG_TOOLS_EXTRA_CLANG_TIDY_BUGPRONE_INVALIDENUMDEFAULTINITIALIZATIONCHECK_H
#define LLVM_CLANG_TOOLS_EXTRA_CLANG_TIDY_BUGPRONE_INVALIDENUMDEFAULTINITIALIZATIONCHECK_H

#include "../ClangTidyCheck.h"

namespace clang::tidy::bugprone {

/// Detects default initialization (to 0) of variables with `enum` type where
/// the enum has no enumerator with value of 0.
///
/// For the user-facing documentation see:
/// http://clang.llvm.org/extra/clang-tidy/checks/bugprone/invalid-enum-default-initialization.html
class InvalidEnumDefaultInitializationCheck : public ClangTidyCheck {
public:
  InvalidEnumDefaultInitializationCheck(StringRef Name,
                                        ClangTidyContext *Context);
  void registerMatchers(ast_matchers::MatchFinder *Finder) override;
  void check(const ast_matchers::MatchFinder::MatchResult &Result) override;
};

} // namespace clang::tidy::bugprone

#endif // LLVM_CLANG_TOOLS_EXTRA_CLANG_TIDY_BUGPRONE_INVALIDENUMDEFAULTINITIALIZATIONCHECK_H
