; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx900 -mattr=+architected-sgprs -global-isel=0 < %s | FileCheck -check-prefixes=GFX9,GFX9-SDAG %s
; RUN: llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx900 -mattr=+architected-sgprs -global-isel=1 < %s | FileCheck -check-prefixes=GFX9,GFX9-GISEL %s
; RUN: llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1200 -global-isel=0 < %s | FileCheck -check-prefixes=GFX12,GFX12-SDAG %s
; RUN: llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1200 -global-isel=1 < %s | FileCheck -check-prefixes=GFX12,GFX12-GISEL %s

define amdgpu_kernel void @workgroup_id_x(ptr addrspace(1) %ptrx) {
;
; GFX9-LABEL: workgroup_id_x:
; GFX9:       ; %bb.0:
; GFX9-NEXT:    s_load_dwordx2 s[0:1], s[8:9], 0x0
; GFX9-NEXT:    v_mov_b32_e32 v0, ttmp9
; GFX9-NEXT:    v_mov_b32_e32 v1, 0
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    global_store_dword v1, v0, s[0:1]
; GFX9-NEXT:    s_endpgm
;
; GFX12-LABEL: workgroup_id_x:
; GFX12:       ; %bb.0:
; GFX12-NEXT:    s_load_b64 s[0:1], s[4:5], 0x0
; GFX12-NEXT:    v_dual_mov_b32 v0, ttmp9 :: v_dual_mov_b32 v1, 0
; GFX12-NEXT:    s_wait_kmcnt 0x0
; GFX12-NEXT:    global_store_b32 v1, v0, s[0:1]
; GFX12-NEXT:    s_endpgm
  %idx = call i32 @llvm.amdgcn.workgroup.id.x()
  store i32 %idx, ptr addrspace(1) %ptrx

  ret void
}

define amdgpu_kernel void @workgroup_id_xy(ptr addrspace(1) %ptrx, ptr addrspace(1) %ptry) {
; GFX9-LABEL: workgroup_id_xy:
; GFX9:       ; %bb.0:
; GFX9-NEXT:    s_load_dwordx4 s[0:3], s[8:9], 0x0
; GFX9-NEXT:    v_mov_b32_e32 v0, ttmp9
; GFX9-NEXT:    v_mov_b32_e32 v1, 0
; GFX9-NEXT:    s_and_b32 s4, ttmp7, 0xffff
; GFX9-NEXT:    v_mov_b32_e32 v2, s4
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    global_store_dword v1, v0, s[0:1]
; GFX9-NEXT:    global_store_dword v1, v2, s[2:3]
; GFX9-NEXT:    s_endpgm
;
; GFX12-LABEL: workgroup_id_xy:
; GFX12:       ; %bb.0:
; GFX12-NEXT:    s_load_b128 s[0:3], s[4:5], 0x0
; GFX12-NEXT:    s_and_b32 s4, ttmp7, 0xffff
; GFX12-NEXT:    v_dual_mov_b32 v0, ttmp9 :: v_dual_mov_b32 v1, 0
; GFX12-NEXT:    v_mov_b32_e32 v2, s4
; GFX12-NEXT:    s_wait_kmcnt 0x0
; GFX12-NEXT:    s_clause 0x1
; GFX12-NEXT:    global_store_b32 v1, v0, s[0:1]
; GFX12-NEXT:    global_store_b32 v1, v2, s[2:3]
; GFX12-NEXT:    s_endpgm
  %idx = call i32 @llvm.amdgcn.workgroup.id.x()
  store i32 %idx, ptr addrspace(1) %ptrx
  %idy = call i32 @llvm.amdgcn.workgroup.id.y()
  store i32 %idy, ptr addrspace(1) %ptry

  ret void
}

define amdgpu_kernel void @workgroup_id_xyz(ptr addrspace(1) %ptrx, ptr addrspace(1) %ptry, ptr addrspace(1) %ptrz) {
; GFX9-LABEL: workgroup_id_xyz:
; GFX9:       ; %bb.0:
; GFX9-NEXT:    s_load_dwordx4 s[0:3], s[8:9], 0x0
; GFX9-NEXT:    s_load_dwordx2 s[4:5], s[8:9], 0x10
; GFX9-NEXT:    v_mov_b32_e32 v0, ttmp9
; GFX9-NEXT:    v_mov_b32_e32 v1, 0
; GFX9-NEXT:    s_and_b32 s6, ttmp7, 0xffff
; GFX9-NEXT:    s_waitcnt lgkmcnt(0)
; GFX9-NEXT:    global_store_dword v1, v0, s[0:1]
; GFX9-NEXT:    v_mov_b32_e32 v0, s6
; GFX9-NEXT:    s_lshr_b32 s0, ttmp7, 16
; GFX9-NEXT:    global_store_dword v1, v0, s[2:3]
; GFX9-NEXT:    v_mov_b32_e32 v0, s0
; GFX9-NEXT:    global_store_dword v1, v0, s[4:5]
; GFX9-NEXT:    s_endpgm
;
; GFX12-LABEL: workgroup_id_xyz:
; GFX12:       ; %bb.0:
; GFX12-NEXT:    s_clause 0x1
; GFX12-NEXT:    s_load_b128 s[0:3], s[4:5], 0x0
; GFX12-NEXT:    s_load_b64 s[4:5], s[4:5], 0x10
; GFX12-NEXT:    s_and_b32 s6, ttmp7, 0xffff
; GFX12-NEXT:    v_dual_mov_b32 v0, ttmp9 :: v_dual_mov_b32 v1, 0
; GFX12-NEXT:    s_lshr_b32 s7, ttmp7, 16
; GFX12-NEXT:    s_delay_alu instid0(SALU_CYCLE_1)
; GFX12-NEXT:    v_dual_mov_b32 v2, s6 :: v_dual_mov_b32 v3, s7
; GFX12-NEXT:    s_wait_kmcnt 0x0
; GFX12-NEXT:    s_clause 0x2
; GFX12-NEXT:    global_store_b32 v1, v0, s[0:1]
; GFX12-NEXT:    global_store_b32 v1, v2, s[2:3]
; GFX12-NEXT:    global_store_b32 v1, v3, s[4:5]
; GFX12-NEXT:    s_endpgm
  %idx = call i32 @llvm.amdgcn.workgroup.id.x()
  store i32 %idx, ptr addrspace(1) %ptrx
  %idy = call i32 @llvm.amdgcn.workgroup.id.y()
  store i32 %idy, ptr addrspace(1) %ptry
  %idz = call i32 @llvm.amdgcn.workgroup.id.z()
  store i32 %idz, ptr addrspace(1) %ptrz

  ret void
}

declare i32 @llvm.amdgcn.workgroup.id.x()
declare i32 @llvm.amdgcn.workgroup.id.y()
declare i32 @llvm.amdgcn.workgroup.id.z()
;; NOTE: These prefixes are unused and the list is autogenerated. Do not add tests below this line:
; GFX12-GISEL: {{.*}}
; GFX12-SDAG: {{.*}}
; GFX9-GISEL: {{.*}}
; GFX9-SDAG: {{.*}}
