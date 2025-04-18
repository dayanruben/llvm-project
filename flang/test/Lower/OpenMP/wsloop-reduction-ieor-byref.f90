! RUN: bbc -emit-hlfir -fopenmp --force-byref-reduction %s -o - | FileCheck %s
! RUN: %flang_fc1 -emit-hlfir -fopenmp -mmlir --force-byref-reduction %s -o - | FileCheck %s

! CHECK-LABEL:   omp.declare_reduction @ieor_byref_i32 : !fir.ref<i32>
! CHECK-SAME:    alloc {
! CHECK:            %[[REF:.*]] = fir.alloca i32
! CHECK:            omp.yield(%[[REF]] : !fir.ref<i32>)
! CHECK-LABEL:   } init {
! CHECK:         ^bb0(%[[VAL_0:.*]]: !fir.ref<i32>, %[[ALLOC:.*]]: !fir.ref<i32>):
! CHECK:            %[[C0_1:.*]] = arith.constant 0 : i32
! CHECK:            fir.store %[[C0_1]] to %[[ALLOC]] : !fir.ref<i32>
! CHECK:            omp.yield(%[[ALLOC]] : !fir.ref<i32>)

! CHECK-LABEL:   } combiner {
! CHECK:         ^bb0(%[[ARG0:.*]]: !fir.ref<i32>, %[[ARG1:.*]]: !fir.ref<i32>):
! CHECK:           %[[LD0:.*]] = fir.load %[[ARG0]] : !fir.ref<i32>
! CHECK:           %[[LD1:.*]] = fir.load %[[ARG1]] : !fir.ref<i32>
! CHECK:           %[[RES:.*]] = arith.xori %[[LD0]], %[[LD1]] : i32
! CHECK:           fir.store %[[RES]] to %[[ARG0]] : !fir.ref<i32>
! CHECK:           omp.yield(%[[ARG0]] : !fir.ref<i32>)
! CHECK:         }

!CHECK-LABEL: @_QPreduction_ieor
!CHECK-SAME: %[[Y_BOX:.*]]: !fir.box<!fir.array<?xi32>>
!CHECK: %[[X_REF:.*]] = fir.alloca i32 {bindc_name = "x", uniq_name = "_QFreduction_ieorEx"}
!CHECK: %[[X_DECL:.*]]:2 = hlfir.declare %[[X_REF]] {uniq_name = "_QFreduction_ieorEx"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
!CHECK: %[[Y_DECL:.*]]:2 = hlfir.declare %[[Y_BOX]] dummy_scope %{{[0-9]+}} {uniq_name = "_QFreduction_ieorEy"} : (!fir.box<!fir.array<?xi32>>, !fir.dscope) -> (!fir.box<!fir.array<?xi32>>, !fir.box<!fir.array<?xi32>>)


!CHECK: omp.parallel
!CHECK: omp.wsloop private(@{{.*}} %{{.*}}#0 -> %[[I_REF:.*]] : !fir.ref<i32>) reduction(byref @ieor_byref_i32 %[[X_DECL]]#0 -> %[[PRV:.+]] : !fir.ref<i32>)
!CHECK-NEXT: omp.loop_nest
!CHECK: %[[I_DECL:.*]]:2 = hlfir.declare %[[I_REF]] {uniq_name = "_QFreduction_ieorEi"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
!CHECK: %[[PRV_DECL:.+]]:2 = hlfir.declare %[[PRV]] {{.*}} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
!CHECK: hlfir.assign %{{.*}} to %[[I_DECL]]#0 : i32, !fir.ref<i32>
!CHECK: %[[I_32:.*]] = fir.load %[[I_DECL]]#0 : !fir.ref<i32>
!CHECK: %[[I_64:.*]] = fir.convert %[[I_32]] : (i32) -> i64
!CHECK: %[[Y_I_REF:.*]] = hlfir.designate %[[Y_DECL]]#0 (%[[I_64]])  : (!fir.box<!fir.array<?xi32>>, i64) -> !fir.ref<i32>
!CHECK: %[[LPRV:.+]] = fir.load %[[PRV_DECL]]#0 : !fir.ref<i32>
!CHECK: %[[Y_I:.*]] = fir.load %[[Y_I_REF]] : !fir.ref<i32>
!CHECK: %[[RES:.+]] = arith.xori %[[LPRV]], %[[Y_I]] : i32
!CHECK: hlfir.assign %[[RES]] to %[[PRV_DECL]]#0 : i32, !fir.ref<i32>
!CHECK: omp.yield
!CHECK: omp.terminator

subroutine reduction_ieor(y)
  integer :: x, y(:)
  x = 0
  !$omp parallel
  !$omp do reduction(ieor:x)
  do i=1, 100
    x = ieor(x, y(i))
  end do
  !$omp end do
  !$omp end parallel
  print *, x
end subroutine
