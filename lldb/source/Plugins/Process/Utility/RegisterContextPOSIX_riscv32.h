//===-- RegisterContextPOSIX_riscv32.h --------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLDB_SOURCE_PLUGINS_PROCESS_UTILITY_REGISTERCONTEXTPOSIX_RISCV32_H
#define LLDB_SOURCE_PLUGINS_PROCESS_UTILITY_REGISTERCONTEXTPOSIX_RISCV32_H

#include "RegisterInfoInterface.h"
#include "RegisterInfoPOSIX_riscv32.h"
#include "lldb-riscv-register-enums.h"
#include "lldb/Target/RegisterContext.h"
#include "lldb/Utility/Log.h"

class RegisterContextPOSIX_riscv32 : public lldb_private::RegisterContext {
public:
  RegisterContextPOSIX_riscv32(
      lldb_private::Thread &thread,
      std::unique_ptr<RegisterInfoPOSIX_riscv32> register_info);

  ~RegisterContextPOSIX_riscv32() override;

  void invalidate();

  void InvalidateAllRegisters() override;

  size_t GetRegisterCount() override;

  virtual size_t GetGPRSize();

  virtual unsigned GetRegisterSize(unsigned reg);

  virtual unsigned GetRegisterOffset(unsigned reg);

  const lldb_private::RegisterInfo *GetRegisterInfoAtIndex(size_t reg) override;

  size_t GetRegisterSetCount() override;

  const lldb_private::RegisterSet *GetRegisterSet(size_t set) override;

protected:
  std::unique_ptr<RegisterInfoPOSIX_riscv32> m_register_info_up;

  virtual const lldb_private::RegisterInfo *GetRegisterInfo();

  bool IsGPR(unsigned reg);

  bool IsFPR(unsigned reg);

  size_t GetFPRSize() { return sizeof(RegisterInfoPOSIX_riscv32::FPR); }

  uint32_t GetRegNumFCSR() const { return fpr_fcsr_riscv; }

  virtual bool ReadGPR() = 0;
  virtual bool ReadFPR() = 0;
  virtual bool WriteGPR() = 0;
  virtual bool WriteFPR() = 0;
};

#endif // LLDB_SOURCE_PLUGINS_PROCESS_UTILITY_REGISTERCONTEXTPOSIX_RISCV32_H
