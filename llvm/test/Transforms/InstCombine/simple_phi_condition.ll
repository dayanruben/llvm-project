; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -S < %s -passes=instcombine | FileCheck %s

define i1 @test_direct_implication(i1 %cond) {
; CHECK-LABEL: @test_direct_implication(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    ret i1 [[COND]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br label %merge

if.false:
  br label %merge

merge:
  %ret = phi i1 [true, %if.true], [false, %if.false]
  ret i1 %ret
}

define i1 @test_inverted_implication(i1 %cond) {
; CHECK-LABEL: @test_inverted_implication(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = xor i1 [[COND]], true
; CHECK-NEXT:    ret i1 [[RET]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br label %merge

if.false:
  br label %merge

merge:
  %ret = phi i1 [false, %if.true], [true, %if.false]
  ret i1 %ret
}

define i1 @test_edge_dominance(i1 %cmp) {
; CHECK-LABEL: @test_edge_dominance(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[CMP:%.*]], label [[IF_END:%.*]], label [[IF_THEN:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    ret i1 [[CMP]]
;
entry:
  br i1 %cmp, label %if.end, label %if.then

if.then:
  br label %if.end

if.end:
  %phi = phi i1 [ true, %entry ], [ false, %if.then ]
  ret i1 %phi
}

define i1 @test_direct_implication_complex_cfg(i1 %cond, i32 %cnt1) {
; CHECK-LABEL: @test_direct_implication_complex_cfg(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br label [[LOOP1:%.*]]
; CHECK:       loop1:
; CHECK-NEXT:    [[IV1:%.*]] = phi i32 [ 0, [[IF_TRUE]] ], [ [[IV1_NEXT:%.*]], [[LOOP1]] ]
; CHECK-NEXT:    [[IV1_NEXT]] = add i32 [[IV1]], 1
; CHECK-NEXT:    [[LOOP_COND_1:%.*]] = icmp slt i32 [[IV1_NEXT]], [[CNT1:%.*]]
; CHECK-NEXT:    br i1 [[LOOP_COND_1]], label [[LOOP1]], label [[IF_TRUE_END:%.*]]
; CHECK:       if.true.end:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    ret i1 [[COND]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br label %loop1

loop1:
  %iv1 = phi i32 [0, %if.true], [%iv1.next, %loop1]
  %iv1.next = add i32 %iv1, 1
  %loop.cond.1 = icmp slt i32 %iv1.next, %cnt1
  br i1 %loop.cond.1, label %loop1, label %if.true.end

if.true.end:
  br label %merge

if.false:
  br label %merge

merge:
  %ret = phi i1 [true, %if.true.end], [false, %if.false]
  ret i1 %ret
}

define i1 @test_inverted_implication_complex_cfg(i1 %cond, i32 %cnt1) {
; CHECK-LABEL: @test_inverted_implication_complex_cfg(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br label [[LOOP1:%.*]]
; CHECK:       loop1:
; CHECK-NEXT:    [[IV1:%.*]] = phi i32 [ 0, [[IF_TRUE]] ], [ [[IV1_NEXT:%.*]], [[LOOP1]] ]
; CHECK-NEXT:    [[IV1_NEXT]] = add i32 [[IV1]], 1
; CHECK-NEXT:    [[LOOP_COND_1:%.*]] = icmp slt i32 [[IV1_NEXT]], [[CNT1:%.*]]
; CHECK-NEXT:    br i1 [[LOOP_COND_1]], label [[LOOP1]], label [[IF_TRUE_END:%.*]]
; CHECK:       if.true.end:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = xor i1 [[COND]], true
; CHECK-NEXT:    ret i1 [[RET]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br label %loop1

loop1:
  %iv1 = phi i32 [0, %if.true], [%iv1.next, %loop1]
  %iv1.next = add i32 %iv1, 1
  %loop.cond.1 = icmp slt i32 %iv1.next, %cnt1
  br i1 %loop.cond.1, label %loop1, label %if.true.end

if.true.end:
  br label %merge

if.false:
  br label %merge

merge:
  %ret = phi i1 [false, %if.true.end], [true, %if.false]
  ret i1 %ret
}

define i1 @test_multiple_predecessors(i1 %cond, i1 %cond2) {
; CHECK-LABEL: @test_multiple_predecessors(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br i1 [[COND2:%.*]], label [[IF2_TRUE:%.*]], label [[IF2_FALSE:%.*]]
; CHECK:       if2.true:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       if2.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    ret i1 [[COND]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br label %merge

if.false:
  br i1 %cond2, label %if2.true, label %if2.false

if2.true:
  br label %merge

if2.false:
  br label %merge

merge:
  %ret = phi i1 [ true, %if.true ], [ false, %if2.true ], [ false, %if2.false ]
  ret i1 %ret
}

define i1 @test_multiple_predecessors_wrong_value(i1 %cond, i1 %cond2) {
; CHECK-LABEL: @test_multiple_predecessors_wrong_value(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br i1 [[COND2:%.*]], label [[IF2_TRUE:%.*]], label [[IF2_FALSE:%.*]]
; CHECK:       if2.true:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       if2.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i1 [ true, [[IF_TRUE]] ], [ true, [[IF2_TRUE]] ], [ false, [[IF2_FALSE]] ]
; CHECK-NEXT:    ret i1 [[RET]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br label %merge

if.false:
  br i1 %cond2, label %if2.true, label %if2.false

if2.true:
  br label %merge

if2.false:
  br label %merge

merge:
  %ret = phi i1 [ true, %if.true ], [ true, %if2.true ], [ false, %if2.false ]
  ret i1 %ret
}

define i1 @test_multiple_predecessors_no_edge_domination(i1 %cond, i1 %cond2) {
; CHECK-LABEL: @test_multiple_predecessors_no_edge_domination(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br i1 [[COND2:%.*]], label [[MERGE:%.*]], label [[IF_FALSE]]
; CHECK:       if.false:
; CHECK-NEXT:    br i1 [[COND2]], label [[IF2_TRUE:%.*]], label [[IF2_FALSE:%.*]]
; CHECK:       if2.true:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       if2.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i1 [ true, [[IF_TRUE]] ], [ false, [[IF2_TRUE]] ], [ false, [[IF2_FALSE]] ]
; CHECK-NEXT:    ret i1 [[RET]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br i1 %cond2, label %merge, label %if.false

if.false:
  br i1 %cond2, label %if2.true, label %if2.false

if2.true:
  br label %merge

if2.false:
  br label %merge

merge:
  %ret = phi i1 [ true, %if.true ], [ false, %if2.true ], [ false, %if2.false ]
  ret i1 %ret
}

define i8 @test_switch(i8 %cond) {
; CHECK-LABEL: @test_switch(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[SW_7:%.*]]
; CHECK-NEXT:      i8 19, label [[SW_19:%.*]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.7:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.19:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       default:
; CHECK-NEXT:    ret i8 42
; CHECK:       merge:
; CHECK-NEXT:    ret i8 [[COND]]
;
entry:
  switch i8 %cond, label %default [
  i8 1, label %sw.1
  i8 7, label %sw.7
  i8 19, label %sw.19
  ]

sw.1:
  br label %merge

sw.7:
  br label %merge

sw.19:
  br label %merge

default:
  ret i8 42

merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %sw.7 ], [ 19, %sw.19 ]
  ret i8 %ret
}

define i8 @test_switch_direct_edge(i8 %cond) {
; CHECK-LABEL: @test_switch_direct_edge(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[SW_7:%.*]]
; CHECK-NEXT:      i8 19, label [[MERGE:%.*]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.7:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       default:
; CHECK-NEXT:    ret i8 42
; CHECK:       merge:
; CHECK-NEXT:    ret i8 [[COND]]
;
entry:
  switch i8 %cond, label %default [
  i8 1, label %sw.1
  i8 7, label %sw.7
  i8 19, label %merge
  ]

sw.1:
  br label %merge

sw.7:
  br label %merge

default:
  ret i8 42

merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %sw.7 ], [ 19, %entry ]
  ret i8 %ret
}

define i8 @test_switch_duplicate_direct_edge(i8 %cond) {
; CHECK-LABEL: @test_switch_duplicate_direct_edge(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[MERGE:%.*]]
; CHECK-NEXT:      i8 19, label [[MERGE]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       default:
; CHECK-NEXT:    ret i8 42
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 1, [[SW_1]] ], [ 7, [[ENTRY:%.*]] ], [ 7, [[ENTRY]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  switch i8 %cond, label %default [
  i8 1, label %sw.1
  i8 7, label %merge
  i8 19, label %merge
  ]

sw.1:
  br label %merge

default:
  ret i8 42

merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %entry ], [ 7, %entry ]
  ret i8 %ret
}

define i8 @test_switch_subset(i8 %cond) {
; CHECK-LABEL: @test_switch_subset(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[SW_7:%.*]]
; CHECK-NEXT:      i8 19, label [[SW_19:%.*]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.7:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.19:
; CHECK-NEXT:    ret i8 24
; CHECK:       default:
; CHECK-NEXT:    ret i8 42
; CHECK:       merge:
; CHECK-NEXT:    ret i8 [[COND]]
;
entry:
  switch i8 %cond, label %default [
  i8 1, label %sw.1
  i8 7, label %sw.7
  i8 19, label %sw.19
  ]

sw.1:
  br label %merge

sw.7:
  br label %merge

sw.19:
  ret i8 24

default:
  ret i8 42

merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %sw.7 ]
  ret i8 %ret
}

define i8 @test_switch_wrong_value(i8 %cond) {
; CHECK-LABEL: @test_switch_wrong_value(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[SW_7:%.*]]
; CHECK-NEXT:      i8 19, label [[SW_19:%.*]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.7:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.19:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       default:
; CHECK-NEXT:    ret i8 42
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 1, [[SW_1]] ], [ 7, [[SW_7]] ], [ 10, [[SW_19]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  switch i8 %cond, label %default [
  i8 1, label %sw.1
  i8 7, label %sw.7
  i8 19, label %sw.19
  ]

sw.1:
  br label %merge

sw.7:
  br label %merge

sw.19:
  br label %merge

default:
  ret i8 42

merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %sw.7 ], [ 10, %sw.19 ]
  ret i8 %ret
}

define i8 @test_switch_inverted(i8 %cond) {
; CHECK-LABEL: @test_switch_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 0, label [[SW_0:%.*]]
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 2, label [[SW_2:%.*]]
; CHECK-NEXT:    ]
; CHECK:       sw.0:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.2:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       default:
; CHECK-NEXT:    ret i8 42
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = xor i8 [[COND]], -1
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  switch i8 %cond, label %default [
  i8 0, label %sw.0
  i8 1, label %sw.1
  i8 2, label %sw.2
  ]

sw.0:
  br label %merge

sw.1:
  br label %merge

sw.2:
  br label %merge

default:
  ret i8 42

merge:
  %ret = phi i8 [ -1, %sw.0 ], [ -2, %sw.1 ], [ -3, %sw.2 ]
  ret i8 %ret
}

define i8 @test_switch_duplicate_edge(i8 %cond) {
; CHECK-LABEL: @test_switch_duplicate_edge(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[SW_7:%.*]]
; CHECK-NEXT:      i8 19, label [[SW_7]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.7:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       default:
; CHECK-NEXT:    ret i8 42
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 1, [[SW_1]] ], [ 7, [[SW_7]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  switch i8 %cond, label %default [
  i8 1, label %sw.1
  i8 7, label %sw.7
  i8 19, label %sw.7
  ]

sw.1:
  br label %merge

sw.7:
  br label %merge

default:
  ret i8 42

merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %sw.7 ]
  ret i8 %ret
}

define i8 @test_switch_default_edge(i8 %cond) {
; CHECK-LABEL: @test_switch_default_edge(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[MERGE:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[SW_7:%.*]]
; CHECK-NEXT:      i8 19, label [[SW_19:%.*]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.7:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.19:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 1, [[SW_1]] ], [ 7, [[SW_7]] ], [ 19, [[SW_19]] ], [ 42, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  switch i8 %cond, label %merge [
  i8 1, label %sw.1
  i8 7, label %sw.7
  i8 19, label %sw.19
  ]

sw.1:
  br label %merge

sw.7:
  br label %merge

sw.19:
  br label %merge

merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %sw.7 ], [ 19, %sw.19 ], [ 42, %entry ]
  ret i8 %ret
}

define i8 @test_switch_default_edge_direct(i8 %cond) {
; CHECK-LABEL: @test_switch_default_edge_direct(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[MERGE:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[SW_7:%.*]]
; CHECK-NEXT:      i8 19, label [[MERGE]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.7:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 1, [[SW_1]] ], [ 7, [[SW_7]] ], [ 19, [[ENTRY:%.*]] ], [ 19, [[ENTRY]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  switch i8 %cond, label %merge [
  i8 1, label %sw.1
  i8 7, label %sw.7
  i8 19, label %merge
  ]
sw.1:
  br label %merge
sw.7:
  br label %merge
merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %sw.7 ], [ 19, %entry ], [ 19, %entry ]
  ret i8 %ret
}

define i8 @test_switch_default_edge_duplicate(i8 %cond) {
; CHECK-LABEL: @test_switch_default_edge_duplicate(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[COND:%.*]], label [[SW_19:%.*]] [
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i8 7, label [[SW_7:%.*]]
; CHECK-NEXT:      i8 19, label [[SW_19]]
; CHECK-NEXT:    ]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.7:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.19:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 1, [[SW_1]] ], [ 7, [[SW_7]] ], [ 19, [[SW_19]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  switch i8 %cond, label %sw.19 [
  i8 1, label %sw.1
  i8 7, label %sw.7
  i8 19, label %sw.19
  ]
sw.1:
  br label %merge
sw.7:
  br label %merge
sw.19:
  br label %merge
merge:
  %ret = phi i8 [ 1, %sw.1 ], [ 7, %sw.7 ], [ 19, %sw.19 ]
  ret i8 %ret
}

define i32 @test_phi_to_zext(i8 noundef %0) {
; CHECK-LABEL: @test_phi_to_zext(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 -1, label [[SW_255:%.*]]
; CHECK-NEXT:      i8 0, label [[SW_0:%.*]]
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.255:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.0:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i32 [ 1, [[SW_1]] ], [ 0, [[SW_0]] ], [ 255, [[SW_255]] ]
; CHECK-NEXT:    ret i32 [[DOT0]]
;
entry:
  switch i8 %0, label %default [
  i8 255, label %sw.255
  i8 0, label %sw.0
  i8 1, label %sw.1
  ]

default:
  unreachable

sw.255:
  br label %merge

sw.0:
  br label %merge

sw.1:
  br label %merge

merge:
  %.0 = phi i32 [ 1, %sw.1 ], [ 0, %sw.0 ], [ 255, %sw.255 ]
  ret i32 %.0
}

define i32 @test_phi_to_zext_inverted(i8 noundef %0) {
; CHECK-LABEL: @test_phi_to_zext_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 -1, label [[SW_255:%.*]]
; CHECK-NEXT:      i8 0, label [[SW_0:%.*]]
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.255:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.0:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i32 [ -256, [[SW_255]] ], [ -2, [[SW_1]] ], [ -1, [[SW_0]] ]
; CHECK-NEXT:    ret i32 [[DOT0]]
;
entry:
  switch i8 %0, label %default [
  i8 255, label %sw.255
  i8 0, label %sw.0
  i8 1, label %sw.1
  ]

default:
  unreachable

sw.255:
  br label %merge

sw.0:
  br label %merge

sw.1:
  br label %merge

merge:
  %.0 = phi i32  [ -256, %sw.255 ], [ -2, %sw.1 ], [ -1, %sw.0 ]
  ret i32 %.0
}

define i8 @test_multiple_predecessors_phi_to_zext(i1 %cond, i1 %cond2) {
; CHECK-LABEL: @test_multiple_predecessors_phi_to_zext(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br i1 [[COND2:%.*]], label [[IF2_TRUE:%.*]], label [[IF2_FALSE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if2.true:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       if2.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 0, [[IF_FALSE]] ], [ 1, [[IF2_TRUE]] ], [ 1, [[IF2_FALSE]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br i1 %cond2, label %if2.true, label %if2.false

if.false:
  br label %merge

if2.true:
  br label %merge

if2.false:
  br label %merge

merge:
  %ret = phi i8 [ 0, %if.false ], [ 1, %if2.true ], [ 1, %if2.false ]
  ret i8 %ret
}

define i32 @test_phi_to_sext(i8 noundef %0) {
; CHECK-LABEL: @test_phi_to_sext(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 -1, label [[SW_255:%.*]]
; CHECK-NEXT:      i8 0, label [[SW_0:%.*]]
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.255:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.0:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i32 [ 1, [[SW_1]] ], [ 0, [[SW_0]] ], [ -1, [[SW_255]] ]
; CHECK-NEXT:    ret i32 [[DOT0]]
;
entry:
  switch i8 %0, label %default [
  i8 255, label %sw.255
  i8 0, label %sw.0
  i8 1, label %sw.1
  ]

default:
  unreachable

sw.255:
  br label %merge

sw.0:
  br label %merge

sw.1:
  br label %merge

merge:
  %.0 = phi i32 [ 1, %sw.1 ], [ 0, %sw.0 ], [ -1, %sw.255 ]
  ret i32 %.0
}

define i32 @test_phi_to_sext_inverted(i8 noundef %0) {
; CHECK-LABEL: @test_phi_to_sext_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 -1, label [[SW_255:%.*]]
; CHECK-NEXT:      i8 0, label [[SW_0:%.*]]
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.255:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.0:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i32 [ -2, [[SW_1]] ], [ -1, [[SW_0]] ], [ 0, [[SW_255]] ]
; CHECK-NEXT:    ret i32 [[DOT0]]
;
entry:
  switch i8 %0, label %default [
  i8 255, label %sw.255
  i8 0, label %sw.0
  i8 1, label %sw.1
  ]

default:
  unreachable

sw.255:
  br label %merge

sw.0:
  br label %merge

sw.1:
  br label %merge

merge:
  %.0 = phi i32 [ -2, %sw.1 ], [ -1, %sw.0 ], [ 0, %sw.255 ]
  ret i32 %.0
}

define i8 @test_multiple_predecessors_phi_to_sext(i1 %cond, i1 %cond2) {
; CHECK-LABEL: @test_multiple_predecessors_phi_to_sext(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br i1 [[COND2:%.*]], label [[IF2_TRUE:%.*]], label [[IF2_FALSE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if2.true:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       if2.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 0, [[IF_FALSE]] ], [ -1, [[IF2_TRUE]] ], [ -1, [[IF2_FALSE]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br i1 %cond2, label %if2.true, label %if2.false

if.false:
  br label %merge

if2.true:
  br label %merge

if2.false:
  br label %merge

merge:
  %ret = phi i8 [ 0, %if.false ], [ -1, %if2.true ], [ -1, %if2.false ]
  ret i8 %ret
}

define i32 @test_neg_value_not_possible_to_zext_or_sext(i8 noundef %0) {
; CHECK-LABEL: @test_neg_value_not_possible_to_zext_or_sext(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i8 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i8 -1, label [[SW_255:%.*]]
; CHECK-NEXT:      i8 0, label [[SW_0:%.*]]
; CHECK-NEXT:      i8 1, label [[SW_1:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.255:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       sw.0:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i32 [ 1, [[SW_1]] ], [ 0, [[SW_0]] ], [ 511, [[SW_255]] ]
; CHECK-NEXT:    ret i32 [[DOT0]]
;
entry:
  switch i8 %0, label %default [
  i8 255, label %sw.255
  i8 0, label %sw.0
  i8 1, label %sw.1
  ]

default:
  unreachable

sw.255:
  br label %merge

sw.0:
  br label %merge

sw.1:
  br label %merge

merge:
  %.0 = phi i32 [ 1, %sw.1 ], [ 0, %sw.0 ], [ 511, %sw.255 ]
  ret i32 %.0
}

define i8 @test_neg_multiple_predecessors_value_not_possible_to_zext_or_sext(i1 %cond, i1 %cond2) {
; CHECK-LABEL: @test_neg_multiple_predecessors_value_not_possible_to_zext_or_sext(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_TRUE:%.*]], label [[IF_FALSE:%.*]]
; CHECK:       if.true:
; CHECK-NEXT:    br i1 [[COND2:%.*]], label [[IF2_TRUE:%.*]], label [[IF2_FALSE:%.*]]
; CHECK:       if.false:
; CHECK-NEXT:    br label [[MERGE:%.*]]
; CHECK:       if2.true:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       if2.false:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[RET:%.*]] = phi i8 [ 0, [[IF_FALSE]] ], [ 1, [[IF2_TRUE]] ], [ -1, [[IF2_FALSE]] ]
; CHECK-NEXT:    ret i8 [[RET]]
;
entry:
  br i1 %cond, label %if.true, label %if.false

if.true:
  br i1 %cond2, label %if2.true, label %if2.false

if.false:
  br label %merge

if2.true:
  br label %merge

if2.false:
  br label %merge

merge:
  %ret = phi i8 [ 0, %if.false ], [ 1, %if2.true ], [ -1, %if2.false ]
  ret i8 %ret
}

define i8 @test_phi_to_trunc(i32 %0) {
; CHECK-LABEL: @test_phi_to_trunc(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i32 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i32 0, label [[MERGE:%.*]]
; CHECK-NEXT:      i32 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i32 255, label [[SW_255:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.255:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i8 [ -1, [[SW_255]] ], [ 1, [[SW_1]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret i8 [[DOT0]]
;
entry:
  switch i32 %0, label %default [
  i32 0, label %merge
  i32 1, label %sw.1
  i32 255, label %sw.255
  ]

default:
  unreachable

sw.1:
  br label %merge

sw.255:
  br label %merge

merge:
  %.0 = phi i8 [ -1, %sw.255 ], [ 1, %sw.1 ], [ 0, %entry ]
  ret i8 %.0
}

define i8 @test_phi_to_trunc_inverted(i32 %0) {
; CHECK-LABEL: @test_phi_to_trunc_inverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i32 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i32 0, label [[MERGE:%.*]]
; CHECK-NEXT:      i32 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i32 255, label [[SW_255:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.255:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i8 [ 0, [[SW_255]] ], [ -2, [[SW_1]] ], [ -1, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret i8 [[DOT0]]
;
entry:
  switch i32 %0, label %default [
  i32 0, label %merge
  i32 1, label %sw.1
  i32 255, label %sw.255
  ]

default:
  unreachable

sw.1:
  br label %merge

sw.255:
  br label %merge

merge:
  %.0 = phi i8 [ 0, %sw.255 ], [ -2, %sw.1 ], [ -1, %entry ]
  ret i8 %.0
}

define i8 @test_neg_phi_to_trunc(i32 %0) {
; CHECK-LABEL: @test_neg_phi_to_trunc(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i32 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i32 0, label [[MERGE:%.*]]
; CHECK-NEXT:      i32 1, label [[SW_1:%.*]]
; CHECK-NEXT:      i32 511, label [[SW_511:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.1:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.511:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i8 [ 2, [[SW_511]] ], [ 1, [[SW_1]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret i8 [[DOT0]]
;
entry:
  switch i32 %0, label %default [
  i32 0, label %merge
  i32 1, label %sw.1
  i32 511, label %sw.511
  ]

default:
  unreachable

sw.1:
  br label %merge

sw.511:
  br label %merge

merge:
  %.0 = phi i8 [ 2, %sw.511 ], [ 1, %sw.1 ], [ 0, %entry ]
  ret i8 %.0
}

define i8 @test_neg_phi_to_trunc_multiple_values_trunc_to_same_value(i32 %0) {
; CHECK-LABEL: @test_neg_phi_to_trunc_multiple_values_trunc_to_same_value(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    switch i32 [[TMP0:%.*]], label [[DEFAULT:%.*]] [
; CHECK-NEXT:      i32 0, label [[MERGE:%.*]]
; CHECK-NEXT:      i32 255, label [[SW_255:%.*]]
; CHECK-NEXT:      i32 511, label [[SW_511:%.*]]
; CHECK-NEXT:    ]
; CHECK:       default:
; CHECK-NEXT:    unreachable
; CHECK:       sw.255:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       sw.511:
; CHECK-NEXT:    br label [[MERGE]]
; CHECK:       merge:
; CHECK-NEXT:    [[DOT0:%.*]] = phi i8 [ -1, [[SW_255]] ], [ -1, [[SW_511]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret i8 [[DOT0]]
;
entry:
  switch i32 %0, label %default [
  i32 0, label %merge
  i32 255, label %sw.255
  i32 511, label %sw.511
  ]

default:
  unreachable

sw.255:
  br label %merge

sw.511:
  br label %merge

merge:
  %.0 = phi i8 [ -1, %sw.255 ], [ -1, %sw.511 ], [ 0, %entry ]
  ret i8 %.0
}
