; RUN: llc -global-isel=0 -mtriple=amdgcn-mesa-mesa3d -mcpu=tahiti < %s | FileCheck -check-prefixes=GCN,LOOP %s
; RUN: llc -global-isel=1 -mtriple=amdgcn-mesa-mesa3d -mcpu=tahiti < %s | FileCheck -check-prefixes=GCN,LOOP %s
; RUN: llc -global-isel=0 -mtriple=amdgcn-mesa-mesa3d -mcpu=hawaii < %s | FileCheck -check-prefixes=GCN,LOOP %s
; RUN: llc -global-isel=1 -mtriple=amdgcn-mesa-mesa3d -mcpu=hawaii < %s | FileCheck -check-prefixes=GCN,LOOP %s
; RUN: llc -global-isel=0 -mtriple=amdgcn-mesa-mesa3d -mcpu=fiji < %s | FileCheck -check-prefixes=GCN,LOOP %s
; RUN: llc -global-isel=1 -mtriple=amdgcn-mesa-mesa3d -mcpu=fiji < %s | FileCheck -check-prefixes=GCN,LOOP %s
; RUN: llc -global-isel=0 -mtriple=amdgcn-mesa-mesa3d -mcpu=gfx900 < %s | FileCheck -check-prefixes=GCN,NOLOOP %s
; RUN: llc -global-isel=1 -mtriple=amdgcn-mesa-mesa3d -mcpu=gfx900 < %s | FileCheck -check-prefixes=GCN,NOLOOP %s
; RUN: llc -global-isel=0 -mtriple=amdgcn-mesa-mesa3d -mcpu=gfx1010 < %s | FileCheck -check-prefixes=GCN,NOLOOP %s
; RUN: llc -global-isel=1 -mtriple=amdgcn-mesa-mesa3d -mcpu=gfx1010 < %s | FileCheck -check-prefixes=GCN,NOLOOP %s
; RUN: llc -global-isel=0 -mtriple=amdgcn-mesa-mesa3d -mcpu=gfx1100 < %s | FileCheck -check-prefixes=GCN,NOLOOP %s
; RUN: llc -global-isel=1 -mtriple=amdgcn-mesa-mesa3d -mcpu=gfx1100 < %s | FileCheck -check-prefixes=GCN,NOLOOP %s

; GCN-LABEL: {{^}}gws_sema_br_offset0:
; NOLOOP-DAG: s_load_{{dword|b32}} [[BAR_NUM:s[0-9]+]]
; NOLOOP-DAG: s_mov_b32 m0, 0{{$}}
; NOLOOP: v_mov_b32_e32 v0, [[BAR_NUM]]
; NOLOOP: ds_gws_sema_br v0 gds{{$}}

; LOOP: s_mov_b32 m0, 0{{$}}
; LOOP: [[LOOP:.LBB[0-9]+_[0-9]+]]:
; LOOP-NEXT: s_setreg_imm32_b32 hwreg(HW_REG_TRAPSTS, 8, 1), 0
; LOOP-NEXT: ds_gws_sema_br v0 gds
; LOOP-NEXT: s_waitcnt vmcnt(0) expcnt(0) lgkmcnt(0)
; LOOP-NEXT: s_getreg_b32 [[GETREG:s[0-9]+]], hwreg(HW_REG_TRAPSTS, 8, 1)
; LOOP-NEXT: s_cmp_lg_u32 [[GETREG]], 0
; LOOP-NEXT: s_cbranch_scc1 [[LOOP]]
define amdgpu_kernel void @gws_sema_br_offset0(i32 %val) #0 {
  call void @llvm.amdgcn.ds.gws.sema.br(i32 %val, i32 0)
  ret void
}

declare void @llvm.amdgcn.ds.gws.sema.br(i32, i32) #0

attributes #0 = { convergent inaccessiblememonly nounwind }
