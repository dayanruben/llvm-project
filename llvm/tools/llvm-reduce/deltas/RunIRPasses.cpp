//===- RunIRPasses.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RunIRPasses.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

extern cl::OptionCategory LLVMReduceOptions;

static cl::opt<std::string>
    PassPipeline("ir-passes",
                 cl::desc("A textual description of the pass pipeline, same as "
                          "what's passed to `opt -passes`."),
                 cl::init("function(sroa,instcombine<no-verify-fixpoint>,gvn,"
                          "simplifycfg,infer-address-spaces)"),
                 cl::cat(LLVMReduceOptions));

void llvm::runIRPassesDeltaPass(Oracle &O, ReducerWorkItem &WorkItem) {
  Module &Program = WorkItem.getModule();
  LoopAnalysisManager LAM;
  FunctionAnalysisManager FAM;
  CGSCCAnalysisManager CGAM;
  ModuleAnalysisManager MAM;

  PassInstrumentationCallbacks PIC;
  PIC.registerShouldRunOptionalPassCallback(
      [&](StringRef, Any) { return !O.shouldKeep(); });
  PassBuilder PB(nullptr, PipelineTuningOptions(), std::nullopt, &PIC);

  PB.registerModuleAnalyses(MAM);
  PB.registerCGSCCAnalyses(CGAM);
  PB.registerFunctionAnalyses(FAM);
  PB.registerLoopAnalyses(LAM);
  PB.crossRegisterProxies(LAM, FAM, CGAM, MAM);

  ModulePassManager MPM;
  if (auto Err = PB.parsePassPipeline(MPM, PassPipeline))
    report_fatal_error(std::move(Err), false);
  MPM.run(Program, MAM);
}
