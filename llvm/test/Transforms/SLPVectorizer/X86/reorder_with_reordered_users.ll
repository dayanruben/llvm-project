; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -passes=slp-vectorizer -mtriple=x86_64-grtev4-linux-gnu -S | FileCheck %s

; This checks that reorderBottomToTop() can handle reordering of a TreeEntry
; which has a user TreeEntry that has already been reordered.
; Here is when the crash occurs:
;
;                        (N4)OrderB
;                         |
;  (N1)OrderA (N2)OrderA (N3)NoOrder
;            \      |     /
;               (Phi)NoOrder
;
;  1. Phi is visited along with its operands (N1,N2,N3). BestOrder is "OrderA".
;  2. Phi along with all its operands (N1,N2,N3) are reordered. The result is:
;
;                          (N4)OrderB
;                           |
;  (N1)NoOrder (N2)NoOrder (N3)OrderA
;            \      |     /
;               (Phi)OrderA
;
;  3. N3 is now visited along with its operand N4. BestOrder is "OrderB".
;  4. N3 and N4 are reordered. The result is this:
;
;                          (N4)NoOrder
;                           |
;  (N1)NoOrder (N2)NoOrder (N3)OrderB
;            \      |     /
;               (Phi)OrderA
;
;  At this point there is a discrepancy between Phi's Operand 2 which are
;  reordered based on OrderA and N3's OrderB. This results in a crash in
;  vectorizeTree() on its way from N3 back to the Phi. The reason is that
;  N3->isSame(Phi's operand 2) returns false and vectorizeTree() skips N3.
;
;  This patch changes the order in which the nodes are visited to bottom-up,
;  which fixes the issue.
;
; NOTE: The crash shows up when reorderTopToBottom() does not reorder the tree,
; so to simulate this we add external store users. Alternatively one can
; comment out reorderTopToBottom() and remove the stores.


define void @reorder_crash(ptr %ptr, i1 %arg) {
; CHECK-LABEL: @reorder_crash(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 %arg, label [[BB0:%.*]], label [[BB12:%.*]]
; CHECK:       bb0:
; CHECK-NEXT:    [[TMP0:%.*]] = load <4 x float>, ptr [[PTR:%.*]], align 4
; CHECK-NEXT:    store <4 x float> [[TMP0]], ptr [[PTR]], align 4
; CHECK-NEXT:    br label [[BB3:%.*]]
; CHECK:       bb12:
; CHECK-NEXT:    br i1 %arg, label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    [[TMP1:%.*]] = load <4 x float>, ptr [[PTR]], align 4
; CHECK-NEXT:    store <4 x float> [[TMP1]], ptr [[PTR]], align 4
; CHECK-NEXT:    br label [[BB3]]
; CHECK:       bb2:
; CHECK-NEXT:    [[TMP2:%.*]] = load <4 x float>, ptr [[PTR]], align 4
; CHECK-NEXT:    [[TMP3:%.*]] = fadd <4 x float> [[TMP2]], zeroinitializer
; CHECK-NEXT:    [[TMP4:%.*]] = shufflevector <4 x float> [[TMP3]], <4 x float> poison, <4 x i32> <i32 3, i32 2, i32 0, i32 1>
; CHECK-NEXT:    br label [[BB3]]
; CHECK:       bb3:
; CHECK-NEXT:    [[TMP5:%.*]] = phi <4 x float> [ [[TMP0]], [[BB0]] ], [ [[TMP1]], [[BB1]] ], [ [[TMP4]], [[BB2]] ]
; CHECK-NEXT:    ret void
;
entry:
  %gep1 = getelementptr inbounds float, ptr %ptr, i64 1
  %gep2 = getelementptr inbounds float, ptr %ptr, i64 2
  %gep3 = getelementptr inbounds float, ptr %ptr, i64 3
  br i1 %arg, label %bb0, label %bb12

bb0:
  ; Used by phi in this order: 1, 0, 2, 3
  %ld00 = load float, ptr %ptr
  %ld01 = load float, ptr %gep1
  %ld02 = load float, ptr %gep2
  %ld03 = load float, ptr %gep3

  ; External store users in natural order 0, 1, 2, 3
  store float %ld00, ptr %ptr
  store float %ld01, ptr %gep1
  store float %ld02, ptr %gep2
  store float %ld03, ptr %gep3
  br label %bb3

bb12:
  br i1 %arg, label %bb1, label %bb2

bb1:
  ; Used by phi in this order: 1, 0, 2, 3
  %ld10 = load float, ptr %ptr
  %ld11 = load float, ptr %gep1
  %ld12 = load float, ptr %gep2
  %ld13 = load float, ptr %gep3

  ; External store users in natural order 0, 1, 2, 3
  store float %ld10, ptr %ptr
  store float %ld11, ptr %gep1
  store float %ld12, ptr %gep2
  store float %ld13, ptr %gep3

  br label %bb3

bb2:
  ; Used by fadd in this order: 2, 3, 0, 1
  %ld20 = load float, ptr %ptr
  %ld21 = load float, ptr %gep1
  %ld22 = load float, ptr %gep2
  %ld23 = load float, ptr %gep3

  ; Used by phi in this order: 0, 1, 2, 3
  %add20 = fadd float %ld22, 0.0
  %add21 = fadd float %ld23, 0.0
  %add22 = fadd float %ld20, 0.0
  %add23 = fadd float %ld21, 0.0
  br label %bb3

bb3:
  %phi0 = phi float [ %ld01, %bb0 ], [ %ld11, %bb1 ], [ %add20, %bb2 ]
  %phi1 = phi float [ %ld00, %bb0 ], [ %ld10, %bb1 ], [ %add21, %bb2 ]
  %phi2 = phi float [ %ld02, %bb0 ], [ %ld12, %bb1 ], [ %add22, %bb2 ]
  %phi3 = phi float [ %ld03, %bb0 ], [ %ld13, %bb1 ], [ %add23, %bb2 ]
  ret void
}
