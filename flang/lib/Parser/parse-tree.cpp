//===-- lib/Parser/parse-tree.cpp -----------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "flang/Parser/parse-tree.h"
#include "flang/Common/idioms.h"
#include "flang/Common/indirection.h"
#include "flang/Parser/tools.h"
#include "flang/Parser/user-state.h"
#include "llvm/Frontend/OpenMP/OMP.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>

namespace Fortran::parser {

// R867
ImportStmt::ImportStmt(common::ImportKind &&k, std::list<Name> &&n)
    : kind{k}, names(std::move(n)) {
  CHECK(kind == common::ImportKind::Default ||
      kind == common::ImportKind::Only || names.empty());
}

// R873
CommonStmt::CommonStmt(std::optional<Name> &&name,
    std::list<CommonBlockObject> &&objects, std::list<Block> &&others) {
  blocks.emplace_front(std::move(name), std::move(objects));
  blocks.splice(blocks.end(), std::move(others));
}

// R901 designator
bool Designator::EndsInBareName() const {
  return common::visit(
      common::visitors{
          [](const DataRef &dr) {
            return std::holds_alternative<Name>(dr.u) ||
                std::holds_alternative<common::Indirection<StructureComponent>>(
                    dr.u);
          },
          [](const Substring &) { return false; },
      },
      u);
}

// R911 data-ref -> part-ref [% part-ref]...
DataRef::DataRef(std::list<PartRef> &&prl) : u{std::move(prl.front().name)} {
  for (bool first{true}; !prl.empty(); first = false, prl.pop_front()) {
    PartRef &pr{prl.front()};
    if (!first) {
      u = common::Indirection<StructureComponent>::Make(
          std::move(*this), std::move(pr.name));
    }
    if (!pr.subscripts.empty()) {
      u = common::Indirection<ArrayElement>::Make(
          std::move(*this), std::move(pr.subscripts));
    }
    if (pr.imageSelector) {
      u = common::Indirection<CoindexedNamedObject>::Make(
          std::move(*this), std::move(*pr.imageSelector));
    }
  }
}

// R1001 - R1022 expression
Expr::Expr(Designator &&x)
    : u{common::Indirection<Designator>::Make(std::move(x))} {}
Expr::Expr(FunctionReference &&x)
    : u{common::Indirection<FunctionReference>::Make(std::move(x))} {}

const std::optional<LoopControl> &DoConstruct::GetLoopControl() const {
  const NonLabelDoStmt &doStmt{
      std::get<Statement<NonLabelDoStmt>>(t).statement};
  const std::optional<LoopControl> &control{
      std::get<std::optional<LoopControl>>(doStmt.t)};
  return control;
}

bool DoConstruct::IsDoNormal() const {
  const std::optional<LoopControl> &control{GetLoopControl()};
  return control && std::holds_alternative<LoopControl::Bounds>(control->u);
}

bool DoConstruct::IsDoWhile() const {
  const std::optional<LoopControl> &control{GetLoopControl()};
  return control && std::holds_alternative<ScalarLogicalExpr>(control->u);
}

bool DoConstruct::IsDoConcurrent() const {
  const std::optional<LoopControl> &control{GetLoopControl()};
  return control && std::holds_alternative<LoopControl::Concurrent>(control->u);
}

static Designator MakeArrayElementRef(
    const Name &name, std::list<Expr> &&subscripts) {
  ArrayElement arrayElement{DataRef{Name{name}}, std::list<SectionSubscript>{}};
  for (Expr &expr : subscripts) {
    arrayElement.subscripts.push_back(
        SectionSubscript{Integer{common::Indirection{std::move(expr)}}});
  }
  return Designator{DataRef{common::Indirection{std::move(arrayElement)}}};
}

static Designator MakeArrayElementRef(
    StructureComponent &&sc, std::list<Expr> &&subscripts) {
  ArrayElement arrayElement{DataRef{common::Indirection{std::move(sc)}},
      std::list<SectionSubscript>{}};
  for (Expr &expr : subscripts) {
    arrayElement.subscripts.push_back(
        SectionSubscript{Integer{common::Indirection{std::move(expr)}}});
  }
  return Designator{DataRef{common::Indirection{std::move(arrayElement)}}};
}

// Set source in any type of node that has it.
template <typename T> T WithSource(CharBlock source, T &&x) {
  x.source = source;
  return std::move(x);
}

static Expr ActualArgToExpr(ActualArgSpec &arg) {
  return common::visit(
      common::visitors{
          [&](common::Indirection<Expr> &y) { return std::move(y.value()); },
          [&](common::Indirection<Variable> &y) {
            return common::visit(
                common::visitors{
                    [&](common::Indirection<Designator> &z) {
                      return WithSource(
                          z.value().source, Expr{std::move(z.value())});
                    },
                    [&](common::Indirection<FunctionReference> &z) {
                      return WithSource(
                          z.value().source, Expr{std::move(z.value())});
                    },
                },
                y.value().u);
          },
          [&](auto &) -> Expr { common::die("unexpected type"); },
      },
      std::get<ActualArg>(arg.t).u);
}

Designator FunctionReference::ConvertToArrayElementRef() {
  std::list<Expr> args;
  for (auto &arg : std::get<std::list<ActualArgSpec>>(v.t)) {
    args.emplace_back(ActualArgToExpr(arg));
  }
  return common::visit(
      common::visitors{
          [&](const Name &name) {
            return WithSource(
                source, MakeArrayElementRef(name, std::move(args)));
          },
          [&](ProcComponentRef &pcr) {
            return WithSource(source,
                MakeArrayElementRef(std::move(pcr.v.thing), std::move(args)));
          },
      },
      std::get<ProcedureDesignator>(v.t).u);
}

StructureConstructor FunctionReference::ConvertToStructureConstructor(
    const semantics::DerivedTypeSpec &derived) {
  Name name{std::get<parser::Name>(std::get<ProcedureDesignator>(v.t).u)};
  std::list<ComponentSpec> components;
  for (auto &arg : std::get<std::list<ActualArgSpec>>(v.t)) {
    std::optional<Keyword> keyword;
    if (auto &kw{std::get<std::optional<Keyword>>(arg.t)}) {
      keyword.emplace(Keyword{Name{kw->v}});
    }
    components.emplace_back(
        std::move(keyword), ComponentDataSource{ActualArgToExpr(arg)});
  }
  DerivedTypeSpec spec{std::move(name), std::list<TypeParamSpec>{}};
  spec.derivedTypeSpec = &derived;
  return StructureConstructor{std::move(spec), std::move(components)};
}

StructureConstructor ArrayElement::ConvertToStructureConstructor(
    const semantics::DerivedTypeSpec &derived) {
  Name name{std::get<parser::Name>(base.u)};
  std::list<ComponentSpec> components;
  for (auto &subscript : subscripts) {
    components.emplace_back(std::optional<Keyword>{},
        ComponentDataSource{std::move(*Unwrap<Expr>(subscript))});
  }
  DerivedTypeSpec spec{std::move(name), std::list<TypeParamSpec>{}};
  spec.derivedTypeSpec = &derived;
  return StructureConstructor{std::move(spec), std::move(components)};
}

Substring ArrayElement::ConvertToSubstring() {
  auto iter{subscripts.begin()};
  CHECK(iter != subscripts.end());
  auto &triplet{std::get<SubscriptTriplet>(iter->u)};
  CHECK(!std::get<2>(triplet.t));
  CHECK(++iter == subscripts.end());
  return Substring{std::move(base),
      SubstringRange{std::get<0>(std::move(triplet.t)),
          std::get<1>(std::move(triplet.t))}};
}

// R1544 stmt-function-stmt
// Convert this stmt-function-stmt to an assignment to the result of a
// pointer-valued function call -- which itself will be converted to a
// much more likely array element assignment statement if it needs
// to be.
Statement<ActionStmt> StmtFunctionStmt::ConvertToAssignment() {
  auto &funcName{std::get<Name>(t)};
  auto &funcArgs{std::get<std::list<Name>>(t)};
  auto &funcExpr{std::get<Scalar<Expr>>(t).thing};
  CharBlock source{funcName.source};
  // Extend source to include closing parenthesis
  if (funcArgs.empty()) {
    CHECK(*source.end() == '(');
    source = CharBlock{source.begin(), source.end() + 1};
  }
  std::list<ActualArgSpec> actuals;
  for (const Name &arg : funcArgs) {
    actuals.emplace_back(std::optional<Keyword>{},
        ActualArg{Expr{WithSource(
            arg.source, Designator{DataRef{Name{arg.source, arg.symbol}}})}});
    source.ExtendToCover(arg.source);
  }
  CHECK(*source.end() == ')');
  source = CharBlock{source.begin(), source.end() + 1};
  FunctionReference funcRef{
      Call{ProcedureDesignator{Name{funcName.source, funcName.symbol}},
          std::move(actuals)}};
  funcRef.source = source;
  auto variable{Variable{common::Indirection{std::move(funcRef)}}};
  return Statement{std::nullopt,
      ActionStmt{common::Indirection{
          AssignmentStmt{std::move(variable), std::move(funcExpr)}}}};
}

CharBlock Variable::GetSource() const {
  return common::visit(
      common::visitors{
          [&](const common::Indirection<Designator> &des) {
            return des.value().source;
          },
          [&](const common::Indirection<parser::FunctionReference> &call) {
            return call.value().source;
          },
      },
      u);
}

llvm::raw_ostream &operator<<(llvm::raw_ostream &os, const Name &x) {
  return os << x.ToString();
}

OmpDirectiveName::OmpDirectiveName(const Verbatim &name) {
  std::string_view nameView{name.source.begin(), name.source.size()};
  std::string nameLower{ToLowerCaseLetters(nameView)};
  // The function getOpenMPDirectiveKind will return OMPD_unknown in two cases:
  // (1) if the given string doesn't match any actual directive, or
  // (2) if the given string was "unknown".
  // The Verbatim(<token>) parser will succeed as long as the given token
  // matches the source.
  // Since using "construct<OmpDirectiveName>(verbatim(...))" will succeed
  // if the verbatim parser succeeds, in order to get OMPD_unknown the
  // token given to Verbatim must be invalid. Because it's an internal issue
  // asserting is ok.
  v = llvm::omp::getOpenMPDirectiveKind(nameLower);
  assert(v != llvm::omp::Directive::OMPD_unknown && "Invalid directive name");
  source = name.source;
}

OmpDependenceType::Value OmpDoacross::GetDepType() const {
  return common::visit( //
      common::visitors{
          [](const OmpDoacross::Sink &) {
            return OmpDependenceType::Value::Sink;
          },
          [](const OmpDoacross::Source &) {
            return OmpDependenceType::Value::Source;
          },
      },
      u);
}

OmpTaskDependenceType::Value OmpDependClause::TaskDep::GetTaskDepType() const {
  using Modifier = OmpDependClause::TaskDep::Modifier;
  auto &modifiers{std::get<std::optional<std::list<Modifier>>>(t)};
  if (modifiers) {
    for (auto &m : *modifiers) {
      if (auto *dep{std::get_if<OmpTaskDependenceType>(&m.u)}) {
        return dep->v;
      }
    }
    llvm_unreachable("expecting OmpTaskDependenceType in TaskDep");
  } else {
    llvm_unreachable("expecting modifiers on OmpDependClause::TaskDep");
  }
}

std::string OmpTraitSelectorName::ToString() const {
  return common::visit( //
      common::visitors{
          [&](Value v) { //
            return std::string(EnumToString(v));
          },
          [&](llvm::omp::Directive d) {
            return llvm::omp::getOpenMPDirectiveName(
                d, llvm::omp::FallbackVersion)
                .str();
          },
          [&](const std::string &s) { //
            return s;
          },
      },
      u);
}

std::string OmpTraitSetSelectorName::ToString() const {
  return std::string(EnumToString(v));
}

llvm::omp::Clause OpenMPAtomicConstruct::GetKind() const {
  const OmpDirectiveSpecification &dirSpec{std::get<OmpBeginDirective>(t)};
  for (auto &clause : dirSpec.Clauses().v) {
    switch (clause.Id()) {
    case llvm::omp::Clause::OMPC_read:
    case llvm::omp::Clause::OMPC_write:
    case llvm::omp::Clause::OMPC_update:
      return clause.Id();
    default:
      break;
    }
  }
  return llvm::omp::Clause::OMPC_update;
}

bool OpenMPAtomicConstruct::IsCapture() const {
  const OmpDirectiveSpecification &dirSpec{std::get<OmpBeginDirective>(t)};
  return llvm::any_of(dirSpec.Clauses().v, [](auto &clause) {
    return clause.Id() == llvm::omp::Clause::OMPC_capture;
  });
}

bool OpenMPAtomicConstruct::IsCompare() const {
  const OmpDirectiveSpecification &dirSpec{std::get<OmpBeginDirective>(t)};
  return llvm::any_of(dirSpec.Clauses().v, [](auto &clause) {
    return clause.Id() == llvm::omp::Clause::OMPC_compare;
  });
}
} // namespace Fortran::parser

template <typename C> static llvm::omp::Clause getClauseIdForClass(C &&) {
  using namespace Fortran;
  using A = llvm::remove_cvref_t<C>; // A is referenced in OMP.inc
  // The code included below contains a sequence of checks like the following
  // for each OpenMP clause
  //   if constexpr (std::is_same_v<A, parser::OmpClause::AcqRel>)
  //     return llvm::omp::Clause::OMPC_acq_rel;
  //   [...]
#define GEN_FLANG_CLAUSE_PARSER_KIND_MAP
#include "llvm/Frontend/OpenMP/OMP.inc"
}

namespace Fortran::parser {
llvm::omp::Clause OmpClause::Id() const {
  return std::visit([](auto &&s) { return getClauseIdForClass(s); }, u);
}

bool OmpDirectiveName::IsExecutionPart() const {
  // Can the directive appear in the execution part of the program.
  llvm::omp::Directive id{v};
  switch (llvm::omp::getDirectiveCategory(id)) {
  case llvm::omp::Category::Executable:
    return true;
  case llvm::omp::Category::Declarative:
    switch (id) {
    case llvm::omp::Directive::OMPD_allocate:
      return true;
    default:
      return false;
    }
    break;
  case llvm::omp::Category::Informational:
    switch (id) {
    case llvm::omp::Directive::OMPD_assume:
      return true;
    default:
      return false;
    }
    break;
  case llvm::omp::Category::Meta:
    return true;
  case llvm::omp::Category::Subsidiary:
    switch (id) {
    // TODO: case llvm::omp::Directive::OMPD_task_iteration:
    case llvm::omp::Directive::OMPD_section:
    case llvm::omp::Directive::OMPD_scan:
      return true;
    default:
      return false;
    }
    break;
  case llvm::omp::Category::Utility:
    switch (id) {
    case llvm::omp::Directive::OMPD_error:
    case llvm::omp::Directive::OMPD_nothing:
      return true;
    default:
      return false;
    }
    break;
  }
  return false;
}

const OmpArgumentList &OmpDirectiveSpecification::Arguments() const {
  static OmpArgumentList empty{decltype(OmpArgumentList::v){}};
  if (auto &arguments = std::get<std::optional<OmpArgumentList>>(t)) {
    return *arguments;
  }
  return empty;
}

const OmpClauseList &OmpDirectiveSpecification::Clauses() const {
  static OmpClauseList empty{decltype(OmpClauseList::v){}};
  if (auto &clauses = std::get<std::optional<OmpClauseList>>(t)) {
    return *clauses;
  }
  return empty;
}
} // namespace Fortran::parser
