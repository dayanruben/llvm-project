; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py UTC_ARGS: --version 5
; Testfile that verifies positive case (0 or 1 only) for BCD builtins national2packed, packed2zoned and zoned2packed.
; RUN: llc -verify-machineinstrs -mcpu=pwr9 -mtriple=powerpc64le-unknown-unknown \
; RUN:   -ppc-asm-full-reg-names  < %s | FileCheck %s

; RUN: llc -verify-machineinstrs -mcpu=pwr9 -mtriple=powerpc64-unknown-unknown \
; RUN:   -ppc-asm-full-reg-names  < %s | FileCheck %s

; RUN: llc -verify-machineinstrs -mcpu=pwr9 -mtriple=powerpc-unknown-unknown \
; RUN:   -ppc-asm-full-reg-names  < %s | FileCheck %s

; RUN: llc -verify-machineinstrs -mcpu=pwr9 -mtriple=powerpc64-ibm-aix-xcoff \
; RUN:   -ppc-asm-full-reg-names  < %s | FileCheck %s

declare <16 x i8> @llvm.ppc.national2packed(<16 x i8>, i32 immarg)

define <16 x i8> @tBcd_National2packed_imm0(<16 x i8> %a) {
; CHECK-LABEL: tBcd_National2packed_imm0:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    bcdcfn. v2, v2, 0
; CHECK-NEXT:    blr
entry:
  %0 = call <16 x i8> @llvm.ppc.national2packed(<16 x i8> %a, i32 0)
  ret <16 x i8> %0
}

define <16 x i8> @tBcd_National2packed_imm1(<16 x i8> %a) {
; CHECK-LABEL: tBcd_National2packed_imm1:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    bcdcfn. v2, v2, 1
; CHECK-NEXT:    blr
entry:
  %0 = call <16 x i8> @llvm.ppc.national2packed(<16 x i8> %a, i32 1)
  ret <16 x i8> %0
}

declare <16 x i8> @llvm.ppc.packed2national(<16 x i8>)

define <16 x i8> @tBcd_Packed2national(<16 x i8> %a) {
; CHECK-LABEL: tBcd_Packed2national:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    bcdctn. v2, v2
; CHECK-NEXT:    blr
entry:
  %0 = call <16 x i8> @llvm.ppc.packed2national(<16 x i8> %a)
  ret <16 x i8> %0
}

declare <16 x i8> @llvm.ppc.packed2zoned(<16 x i8>, i32 immarg)

define <16 x i8> @tBcd_Packed2zoned_imm0(<16 x i8> %a) {
; CHECK-LABEL: tBcd_Packed2zoned_imm0:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    bcdctz. v2, v2, 0
; CHECK-NEXT:    blr
entry:
  %0 = call <16 x i8> @llvm.ppc.packed2zoned(<16 x i8> %a, i32 0)
  ret <16 x i8> %0
}

define <16 x i8> @tBcd_Packed2zoned_imm1(<16 x i8> %a) {
; CHECK-LABEL: tBcd_Packed2zoned_imm1:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    bcdctz. v2, v2, 1
; CHECK-NEXT:    blr
entry:
  %0 = call <16 x i8> @llvm.ppc.packed2zoned(<16 x i8> %a, i32 1)
  ret <16 x i8> %0
}

declare <16 x i8> @llvm.ppc.zoned2packed(<16 x i8>, i32 immarg)

define <16 x i8> @tBcd_Zoned2packed_imm0(<16 x i8> %a) {
; CHECK-LABEL: tBcd_Zoned2packed_imm0:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    bcdcfz. v2, v2, 0
; CHECK-NEXT:    blr
entry:
  %0 = call <16 x i8> @llvm.ppc.zoned2packed(<16 x i8> %a, i32 0)
  ret <16 x i8> %0
}

define <16 x i8> @tBcd_Zoned2packed_imm1(<16 x i8> %a) {
; CHECK-LABEL: tBcd_Zoned2packed_imm1:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    bcdcfz. v2, v2, 1
; CHECK-NEXT:    blr
entry:
  %0 = call <16 x i8> @llvm.ppc.zoned2packed(<16 x i8> %a, i32 1)
  ret <16 x i8> %0
}
