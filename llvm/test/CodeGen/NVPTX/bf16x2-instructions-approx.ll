; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py UTC_ARGS: --version 5
; RUN: llc < %s -mtriple=nvptx64 -mcpu=sm_80 -mattr=+ptx71 --enable-unsafe-fp-math | FileCheck --check-prefixes=CHECK %s
; RUN: %if ptxas-11.8 %{ llc < %s -mtriple=nvptx64 -mcpu=sm_80 -mattr=+ptx71 --enable-unsafe-fp-math | %ptxas-verify -arch=sm_80 %}

target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"

declare <2 x bfloat> @llvm.sin.f16(<2 x bfloat> %a) #0
declare <2 x bfloat> @llvm.cos.f16(<2 x bfloat> %a) #0

define <2 x bfloat> @test_sin(<2 x bfloat> %a) #0 #1 {
; CHECK-LABEL: test_sin(
; CHECK:       {
; CHECK-NEXT:    .reg .b16 %rs<3>;
; CHECK-NEXT:    .reg .b32 %r<7>;
; CHECK-EMPTY:
; CHECK-NEXT:  // %bb.0:
; CHECK-NEXT:    ld.param.b32 %r1, [test_sin_param_0];
; CHECK-NEXT:    mov.b32 {%rs1, %rs2}, %r1;
; CHECK-NEXT:    cvt.f32.bf16 %r2, %rs1;
; CHECK-NEXT:    sin.approx.f32 %r3, %r2;
; CHECK-NEXT:    cvt.f32.bf16 %r4, %rs2;
; CHECK-NEXT:    sin.approx.f32 %r5, %r4;
; CHECK-NEXT:    cvt.rn.bf16x2.f32 %r6, %r5, %r3;
; CHECK-NEXT:    st.param.b32 [func_retval0], %r6;
; CHECK-NEXT:    ret;
  %r = call <2 x bfloat> @llvm.sin.f16(<2 x bfloat> %a)
  ret <2 x bfloat> %r
}

define <2 x bfloat> @test_cos(<2 x bfloat> %a) #0 #1 {
; CHECK-LABEL: test_cos(
; CHECK:       {
; CHECK-NEXT:    .reg .b16 %rs<3>;
; CHECK-NEXT:    .reg .b32 %r<7>;
; CHECK-EMPTY:
; CHECK-NEXT:  // %bb.0:
; CHECK-NEXT:    ld.param.b32 %r1, [test_cos_param_0];
; CHECK-NEXT:    mov.b32 {%rs1, %rs2}, %r1;
; CHECK-NEXT:    cvt.f32.bf16 %r2, %rs1;
; CHECK-NEXT:    cos.approx.f32 %r3, %r2;
; CHECK-NEXT:    cvt.f32.bf16 %r4, %rs2;
; CHECK-NEXT:    cos.approx.f32 %r5, %r4;
; CHECK-NEXT:    cvt.rn.bf16x2.f32 %r6, %r5, %r3;
; CHECK-NEXT:    st.param.b32 [func_retval0], %r6;
; CHECK-NEXT:    ret;
  %r = call <2 x bfloat> @llvm.cos.f16(<2 x bfloat> %a)
  ret <2 x bfloat> %r
}

