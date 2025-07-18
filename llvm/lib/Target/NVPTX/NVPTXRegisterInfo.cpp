//===- NVPTXRegisterInfo.cpp - NVPTX Register Information -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the NVPTX implementation of the TargetRegisterInfo class.
//
//===----------------------------------------------------------------------===//

#include "NVPTXRegisterInfo.h"
#include "MCTargetDesc/NVPTXInstPrinter.h"
#include "NVPTX.h"
#include "NVPTXTargetMachine.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/TargetInstrInfo.h"

using namespace llvm;

#define DEBUG_TYPE "nvptx-reg-info"

namespace llvm {
StringRef getNVPTXRegClassName(TargetRegisterClass const *RC) {
  if (RC == &NVPTX::B128RegClass)
    return ".b128";
  if (RC == &NVPTX::B64RegClass)
    // We use untyped (.b) integer registers here as NVCC does.
    // Correctness of generated code does not depend on register type,
    // but using .s/.u registers runs into ptxas bug that prevents
    // assembly of otherwise valid PTX into SASS. Despite PTX ISA
    // specifying only argument size for fp16 instructions, ptxas does
    // not allow using .s16 or .u16 arguments for .fp16
    // instructions. At the same time it allows using .s32/.u32
    // arguments for .fp16v2 instructions:
    //
    //   .reg .b16 rb16
    //   .reg .s16 rs16
    //   add.f16 rb16,rb16,rb16; // OK
    //   add.f16 rs16,rs16,rs16; // Arguments mismatch for instruction 'add'
    // but:
    //   .reg .b32 rb32
    //   .reg .s32 rs32
    //   add.f16v2 rb32,rb32,rb32; // OK
    //   add.f16v2 rs32,rs32,rs32; // OK
    return ".b64";
  if (RC == &NVPTX::B32RegClass)
    return ".b32";
  if (RC == &NVPTX::B16RegClass)
    return ".b16";
  if (RC == &NVPTX::B1RegClass)
    return ".pred";
  if (RC == &NVPTX::SpecialRegsRegClass)
    return "!Special!";
  return "INTERNAL";
}

StringRef getNVPTXRegClassStr(TargetRegisterClass const *RC) {
  if (RC == &NVPTX::B128RegClass)
    return "%rq";
  if (RC == &NVPTX::B64RegClass)
    return "%rd";
  if (RC == &NVPTX::B32RegClass)
    return "%r";
  if (RC == &NVPTX::B16RegClass)
    return "%rs";
  if (RC == &NVPTX::B1RegClass)
    return "%p";
  if (RC == &NVPTX::SpecialRegsRegClass)
    return "!Special!";
  return "INTERNAL";
}
} // namespace llvm

NVPTXRegisterInfo::NVPTXRegisterInfo()
    : NVPTXGenRegisterInfo(0), StrPool(StrAlloc) {}

#define GET_REGINFO_TARGET_DESC
#include "NVPTXGenRegisterInfo.inc"

/// NVPTX Callee Saved Registers
const MCPhysReg *
NVPTXRegisterInfo::getCalleeSavedRegs(const MachineFunction *) const {
  static const MCPhysReg CalleeSavedRegs[] = { 0 };
  return CalleeSavedRegs;
}

BitVector NVPTXRegisterInfo::getReservedRegs(const MachineFunction &MF) const {
  BitVector Reserved(getNumRegs());
  for (unsigned Reg = NVPTX::ENVREG0; Reg <= NVPTX::ENVREG31; ++Reg) {
    markSuperRegs(Reserved, Reg);
  }
  markSuperRegs(Reserved, NVPTX::VRFrame32);
  markSuperRegs(Reserved, NVPTX::VRFrameLocal32);
  markSuperRegs(Reserved, NVPTX::VRFrame64);
  markSuperRegs(Reserved, NVPTX::VRFrameLocal64);
  markSuperRegs(Reserved, NVPTX::VRDepot);
  return Reserved;
}

bool NVPTXRegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator II,
                                            int SPAdj, unsigned FIOperandNum,
                                            RegScavenger *) const {
  assert(SPAdj == 0 && "Unexpected");

  MachineInstr &MI = *II;
  if (MI.isLifetimeMarker()) {
    MI.eraseFromParent();
    return true;
  }

  const int FrameIndex = MI.getOperand(FIOperandNum).getIndex();

  const MachineFunction &MF = *MI.getParent()->getParent();
  const int Offset = MF.getFrameInfo().getObjectOffset(FrameIndex) +
                     MI.getOperand(FIOperandNum + 1).getImm();

  // Using I0 as the frame pointer
  MI.getOperand(FIOperandNum).ChangeToRegister(getFrameRegister(MF), false);
  MI.getOperand(FIOperandNum + 1).ChangeToImmediate(Offset);
  return false;
}

Register NVPTXRegisterInfo::getFrameRegister(const MachineFunction &MF) const {
  const NVPTXTargetMachine &TM =
      static_cast<const NVPTXTargetMachine &>(MF.getTarget());
  return TM.is64Bit() ? NVPTX::VRFrame64 : NVPTX::VRFrame32;
}

Register
NVPTXRegisterInfo::getFrameLocalRegister(const MachineFunction &MF) const {
  const NVPTXTargetMachine &TM =
      static_cast<const NVPTXTargetMachine &>(MF.getTarget());
  return TM.is64Bit() ? NVPTX::VRFrameLocal64 : NVPTX::VRFrameLocal32;
}

void NVPTXRegisterInfo::clearDebugRegisterMap() const {
  debugRegisterMap.clear();
}

static uint64_t encodeRegisterForDwarf(StringRef RegisterName) {
  if (RegisterName.size() > 8)
    // The name is more than 8 characters long, and so won't fit into 64 bits.
    return 0;

  // Encode the name string into a DWARF register number using cuda-gdb's
  // encoding.  See cuda_check_dwarf2_reg_ptx_virtual_register in cuda-tdep.c,
  // https://github.com/NVIDIA/cuda-gdb/blob/e5cf3bddae520ffb326f95b4d98ce5c7474b828b/gdb/cuda/cuda-tdep.c#L353
  // IE the bytes of the string are concatenated in reverse into a single
  // number, which is stored in ULEB128, but in practice must be no more than 8
  // bytes (excluding null terminator, which is not included).
  uint64_t result = 0;
  for (unsigned char c : RegisterName)
    result = (result << 8) | c;
  return result;
}

void NVPTXRegisterInfo::addToDebugRegisterMap(
    uint64_t preEncodedVirtualRegister, StringRef RegisterName) const {
  uint64_t mapped = encodeRegisterForDwarf(RegisterName);
  if (mapped == 0)
    return;
  debugRegisterMap.insert({preEncodedVirtualRegister, mapped});
}

int64_t NVPTXRegisterInfo::getDwarfRegNum(MCRegister RegNum, bool isEH) const {
  StringRef Name = NVPTXInstPrinter::getRegisterName(RegNum.id());
  // In NVPTXFrameLowering.cpp, we do arrange for %Depot to be accessible from
  // %SP. Using the %Depot register doesn't provide any debug info in
  // cuda-gdb, but switching it to %SP does.
  if (RegNum.id() == NVPTX::VRDepot)
    Name = "%SP";
  return encodeRegisterForDwarf(Name);
}

int64_t NVPTXRegisterInfo::getDwarfRegNumForVirtReg(Register RegNum,
                                                    bool isEH) const {
  assert(RegNum.isVirtual());
  uint64_t lookup = debugRegisterMap.lookup(RegNum.id());
  if (lookup)
    return lookup;
  return -1;
}
