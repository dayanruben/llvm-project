//===--- QualifiedAutoCheck.cpp - clang-tidy ------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "QualifiedAutoCheck.h"
#include "../utils/LexerUtils.h"
#include "../utils/Matchers.h"
#include "../utils/OptionsUtils.h"
#include "clang/ASTMatchers/ASTMatchers.h"
#include "llvm/ADT/SmallVector.h"
#include <optional>

using namespace clang::ast_matchers;

namespace clang::tidy::readability {

namespace {

// FIXME move to ASTMatchers
AST_MATCHER_P(QualType, hasUnqualifiedType,
              ast_matchers::internal::Matcher<QualType>, InnerMatcher) {
  return InnerMatcher.matches(Node.getUnqualifiedType(), Finder, Builder);
}

enum class Qualifier { Const, Volatile, Restrict };

std::optional<Token> findQualToken(const VarDecl *Decl, Qualifier Qual,
                                   const MatchFinder::MatchResult &Result) {
  // Since either of the locs can be in a macro, use `makeFileCharRange` to be
  // sure that we have a consistent `CharSourceRange`, located entirely in the
  // source file.

  assert((Qual == Qualifier::Const || Qual == Qualifier::Volatile ||
          Qual == Qualifier::Restrict) &&
         "Invalid Qualifier");

  SourceLocation BeginLoc = Decl->getQualifierLoc().getBeginLoc();
  if (BeginLoc.isInvalid())
    BeginLoc = Decl->getBeginLoc();
  SourceLocation EndLoc = Decl->getLocation();

  CharSourceRange FileRange = Lexer::makeFileCharRange(
      CharSourceRange::getCharRange(BeginLoc, EndLoc), *Result.SourceManager,
      Result.Context->getLangOpts());

  if (FileRange.isInvalid())
    return std::nullopt;

  tok::TokenKind Tok = Qual == Qualifier::Const      ? tok::kw_const
                       : Qual == Qualifier::Volatile ? tok::kw_volatile
                                                     : tok::kw_restrict;

  return utils::lexer::getQualifyingToken(Tok, FileRange, *Result.Context,
                                          *Result.SourceManager);
}

std::optional<SourceRange>
getTypeSpecifierLocation(const VarDecl *Var,
                         const MatchFinder::MatchResult &Result) {
  SourceRange TypeSpecifier(
      Var->getTypeSpecStartLoc(),
      Var->getTypeSpecEndLoc().getLocWithOffset(Lexer::MeasureTokenLength(
          Var->getTypeSpecEndLoc(), *Result.SourceManager,
          Result.Context->getLangOpts())));

  if (TypeSpecifier.getBegin().isMacroID() ||
      TypeSpecifier.getEnd().isMacroID())
    return std::nullopt;
  return TypeSpecifier;
}

std::optional<SourceRange> mergeReplacementRange(SourceRange &TypeSpecifier,
                                                 const Token &ConstToken) {
  if (TypeSpecifier.getBegin().getLocWithOffset(-1) == ConstToken.getEndLoc()) {
    TypeSpecifier.setBegin(ConstToken.getLocation());
    return std::nullopt;
  }
  if (TypeSpecifier.getEnd().getLocWithOffset(1) == ConstToken.getLocation()) {
    TypeSpecifier.setEnd(ConstToken.getEndLoc());
    return std::nullopt;
  }
  return SourceRange(ConstToken.getLocation(), ConstToken.getEndLoc());
}

bool isPointerConst(QualType QType) {
  QualType Pointee = QType->getPointeeType();
  assert(!Pointee.isNull() && "can't have a null Pointee");
  return Pointee.isConstQualified();
}

bool isAutoPointerConst(QualType QType) {
  QualType Pointee =
      cast<AutoType>(QType->getPointeeType().getTypePtr())->desugar();
  assert(!Pointee.isNull() && "can't have a null Pointee");
  return Pointee.isConstQualified();
}

} // namespace

QualifiedAutoCheck::QualifiedAutoCheck(StringRef Name,
                                       ClangTidyContext *Context)
    : ClangTidyCheck(Name, Context),
      AddConstToQualified(Options.get("AddConstToQualified", true)),
      AllowedTypes(
          utils::options::parseStringList(Options.get("AllowedTypes", ""))),
      IgnoreAliasing(Options.get("IgnoreAliasing", true)) {}

void QualifiedAutoCheck::storeOptions(ClangTidyOptions::OptionMap &Opts) {
  Options.store(Opts, "AddConstToQualified", AddConstToQualified);
  Options.store(Opts, "AllowedTypes",
                utils::options::serializeStringList(AllowedTypes));
  Options.store(Opts, "IgnoreAliasing", IgnoreAliasing);
}

void QualifiedAutoCheck::registerMatchers(MatchFinder *Finder) {
  auto ExplicitSingleVarDecl =
      [](const ast_matchers::internal::Matcher<VarDecl> &InnerMatcher,
         llvm::StringRef ID) {
        return declStmt(
            unless(isInTemplateInstantiation()),
            hasSingleDecl(
                varDecl(unless(isImplicit()), InnerMatcher).bind(ID)));
      };
  auto ExplicitSingleVarDeclInTemplate =
      [](const ast_matchers::internal::Matcher<VarDecl> &InnerMatcher,
         llvm::StringRef ID) {
        return declStmt(
            isInTemplateInstantiation(),
            hasSingleDecl(
                varDecl(unless(isImplicit()), InnerMatcher).bind(ID)));
      };

  auto IsBoundToType = refersToType(equalsBoundNode("type"));
  auto UnlessFunctionType = unless(hasUnqualifiedDesugaredType(functionType()));

  auto IsPointerType = [this](const auto &...InnerMatchers) {
    if (this->IgnoreAliasing) {
      return qualType(
          hasUnqualifiedDesugaredType(pointerType(pointee(InnerMatchers...))));
    } else {
      return qualType(
          anyOf(qualType(pointerType(pointee(InnerMatchers...))),
                qualType(substTemplateTypeParmType(hasReplacementType(
                    pointerType(pointee(InnerMatchers...)))))));
    }
  };

  auto IsAutoDeducedToPointer =
      [IsPointerType](const std::vector<StringRef> &AllowedTypes,
                      const auto &...InnerMatchers) {
        return autoType(hasDeducedType(
            IsPointerType(InnerMatchers...),
            unless(hasUnqualifiedType(
                matchers::matchesAnyListedTypeName(AllowedTypes, false))),
            unless(pointerType(pointee(hasUnqualifiedType(
                matchers::matchesAnyListedTypeName(AllowedTypes, false)))))));
      };

  Finder->addMatcher(
      ExplicitSingleVarDecl(
          hasType(IsAutoDeducedToPointer(AllowedTypes, UnlessFunctionType)),
          "auto"),
      this);

  Finder->addMatcher(
      ExplicitSingleVarDeclInTemplate(
          allOf(hasType(IsAutoDeducedToPointer(
                    AllowedTypes, hasUnqualifiedType(qualType().bind("type")),
                    UnlessFunctionType)),
                anyOf(hasAncestor(
                          functionDecl(hasAnyTemplateArgument(IsBoundToType))),
                      hasAncestor(classTemplateSpecializationDecl(
                          hasAnyTemplateArgument(IsBoundToType))))),
          "auto"),
      this);
  if (!AddConstToQualified)
    return;
  Finder->addMatcher(ExplicitSingleVarDecl(
                         hasType(pointerType(pointee(autoType()))), "auto_ptr"),
                     this);
  Finder->addMatcher(
      ExplicitSingleVarDecl(hasType(lValueReferenceType(pointee(autoType()))),
                            "auto_ref"),
      this);
}

void QualifiedAutoCheck::check(const MatchFinder::MatchResult &Result) {
  if (const auto *Var = Result.Nodes.getNodeAs<VarDecl>("auto")) {
    SourceRange TypeSpecifier;
    if (std::optional<SourceRange> TypeSpec =
            getTypeSpecifierLocation(Var, Result)) {
      TypeSpecifier = *TypeSpec;
    } else
      return;

    llvm::SmallVector<SourceRange, 4> RemoveQualifiersRange;
    auto CheckQualifier = [&](bool IsPresent, Qualifier Qual) {
      if (IsPresent) {
        std::optional<Token> Token = findQualToken(Var, Qual, Result);
        if (!Token || Token->getLocation().isMacroID())
          return true; // Disregard this VarDecl.
        if (std::optional<SourceRange> Result =
                mergeReplacementRange(TypeSpecifier, *Token))
          RemoveQualifiersRange.push_back(*Result);
      }
      return false;
    };

    bool IsLocalConst = Var->getType().isLocalConstQualified();
    bool IsLocalVolatile = Var->getType().isLocalVolatileQualified();
    bool IsLocalRestrict = Var->getType().isLocalRestrictQualified();

    if (CheckQualifier(IsLocalConst, Qualifier::Const) ||
        CheckQualifier(IsLocalVolatile, Qualifier::Volatile) ||
        CheckQualifier(IsLocalRestrict, Qualifier::Restrict))
      return;

    // Check for bridging the gap between the asterisk and name.
    if (Var->getLocation() == TypeSpecifier.getEnd().getLocWithOffset(1))
      TypeSpecifier.setEnd(TypeSpecifier.getEnd().getLocWithOffset(1));

    CharSourceRange FixItRange = CharSourceRange::getCharRange(TypeSpecifier);
    if (FixItRange.isInvalid())
      return;

    SourceLocation FixitLoc = FixItRange.getBegin();
    for (SourceRange &Range : RemoveQualifiersRange) {
      if (Range.getBegin() < FixitLoc)
        FixitLoc = Range.getBegin();
    }

    std::string ReplStr = [&] {
      llvm::StringRef PtrConst = isPointerConst(Var->getType()) ? "const " : "";
      llvm::StringRef LocalConst = IsLocalConst ? "const " : "";
      llvm::StringRef LocalVol = IsLocalVolatile ? "volatile " : "";
      llvm::StringRef LocalRestrict = IsLocalRestrict ? "__restrict " : "";
      return (PtrConst + "auto *" + LocalConst + LocalVol + LocalRestrict)
          .str();
    }();

    DiagnosticBuilder Diag =
        diag(FixitLoc,
             "'%select{|const }0%select{|volatile }1%select{|__restrict }2auto "
             "%3' can be declared as '%4%3'")
        << IsLocalConst << IsLocalVolatile << IsLocalRestrict << Var->getName()
        << ReplStr;

    for (SourceRange &Range : RemoveQualifiersRange) {
      Diag << FixItHint::CreateRemoval(CharSourceRange::getCharRange(Range));
    }

    Diag << FixItHint::CreateReplacement(FixItRange, ReplStr);
    return;
  }
  if (const auto *Var = Result.Nodes.getNodeAs<VarDecl>("auto_ptr")) {
    if (!isPointerConst(Var->getType()))
      return; // Pointer isn't const, no need to add const qualifier.
    if (!isAutoPointerConst(Var->getType()))
      return; // Const isn't wrapped in the auto type, so must be declared
              // explicitly.

    if (Var->getType().isLocalConstQualified()) {
      std::optional<Token> Token = findQualToken(Var, Qualifier::Const, Result);
      if (!Token || Token->getLocation().isMacroID())
        return;
    }
    if (Var->getType().isLocalVolatileQualified()) {
      std::optional<Token> Token =
          findQualToken(Var, Qualifier::Volatile, Result);
      if (!Token || Token->getLocation().isMacroID())
        return;
    }
    if (Var->getType().isLocalRestrictQualified()) {
      std::optional<Token> Token =
          findQualToken(Var, Qualifier::Restrict, Result);
      if (!Token || Token->getLocation().isMacroID())
        return;
    }

    if (std::optional<SourceRange> TypeSpec =
            getTypeSpecifierLocation(Var, Result)) {
      if (TypeSpec->isInvalid() || TypeSpec->getBegin().isMacroID() ||
          TypeSpec->getEnd().isMacroID())
        return;
      SourceLocation InsertPos = TypeSpec->getBegin();
      diag(InsertPos,
           "'auto *%select{|const }0%select{|volatile }1%2' can be declared as "
           "'const auto *%select{|const }0%select{|volatile }1%2'")
          << Var->getType().isLocalConstQualified()
          << Var->getType().isLocalVolatileQualified() << Var->getName()
          << FixItHint::CreateInsertion(InsertPos, "const ");
    }
    return;
  }
  if (const auto *Var = Result.Nodes.getNodeAs<VarDecl>("auto_ref")) {
    if (!isPointerConst(Var->getType()))
      return; // Pointer isn't const, no need to add const qualifier.
    if (!isAutoPointerConst(Var->getType()))
      // Const isn't wrapped in the auto type, so must be declared explicitly.
      return;

    if (std::optional<SourceRange> TypeSpec =
            getTypeSpecifierLocation(Var, Result)) {
      if (TypeSpec->isInvalid() || TypeSpec->getBegin().isMacroID() ||
          TypeSpec->getEnd().isMacroID())
        return;
      SourceLocation InsertPos = TypeSpec->getBegin();
      diag(InsertPos, "'auto &%0' can be declared as 'const auto &%0'")
          << Var->getName() << FixItHint::CreateInsertion(InsertPos, "const ");
    }
    return;
  }
}

} // namespace clang::tidy::readability
