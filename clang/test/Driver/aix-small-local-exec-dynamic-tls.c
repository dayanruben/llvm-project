// RUN: %clang --target=powerpc64-unknown-aix -S -emit-llvm %s -o - | FileCheck --check-prefix=CHECK-DEFAULT %s
// RUN: %clang --target=powerpc-unknown-aix -S -emit-llvm %s -o - | FileCheck --check-prefix=CHECK-DEFAULT %s
// RUN: %clang --target=powerpc64le-unknown-linux-gnu -S -emit-llvm %s -o - | FileCheck --check-prefix=CHECK-DEFAULT %s
// RUN: %clang --target=powerpc64-unknown-linux-gnu -S -emit-llvm %s -o - | FileCheck --check-prefix=CHECK-DEFAULT %s

// RUN: %clang --target=powerpc64-unknown-aix -maix-small-local-exec-tls -S -emit-llvm \
// RUN:    %s -o - | FileCheck %s --check-prefix=CHECK-AIX_SMALL_LOCALEXEC_TLS

// RUN: %clang --target=powerpc64-unknown-aix -maix-small-local-dynamic-tls -S -emit-llvm \
// RUN:    %s -o - | FileCheck %s --check-prefix=CHECK-AIX_SMALL_LOCALDYNAMIC_TLS

// RUN: not %clang --target=powerpc-unknown-aix -maix-small-local-exec-tls \
// RUN:    -fsyntax-only %s 2>&1 | FileCheck --check-prefix=CHECK-UNSUPPORTED-AIX32 %s
// RUN: not %clang --target=powerpc64le-unknown-linux-gnu -maix-small-local-exec-tls \
// RUN:    -fsyntax-only %s 2>&1 | FileCheck --check-prefix=CHECK-UNSUPPORTED-LINUX %s
// RUN: not %clang --target=powerpc64-unknown-linux-gnu -maix-small-local-exec-tls \
// RUN:    -fsyntax-only %s 2>&1 | FileCheck --check-prefix=CHECK-UNSUPPORTED-LINUX %s
// RUN: not %clang --target=powerpc64-unknown-aix -maix-small-local-exec-tls \
// RUN:    -fsyntax-only -fno-data-sections %s 2>&1 | \
// RUN:    FileCheck --check-prefix=CHECK-UNSUPPORTED-NO-DATASEC %s
// RUN: not %clang --target=powerpc64-unknown-linux-gnu -maix-small-local-exec-tls \
// RUN:    -fsyntax-only -fno-data-sections %s 2>&1 | \
// RUN:    FileCheck --check-prefix=CHECK-UNSUPPORTED-NO-DATASEC %s

// RUN: not %clang --target=powerpc-unknown-aix -maix-small-local-dynamic-tls \
// RUN:    -fsyntax-only %s 2>&1 | FileCheck --check-prefix=CHECK-UNSUPPORTED-AIX32 %s
// RUN: not %clang --target=powerpc64le-unknown-linux-gnu -maix-small-local-dynamic-tls \
// RUN:    -fsyntax-only %s 2>&1 | FileCheck --check-prefix=CHECK-UNSUPPORTED-LINUX %s
// RUN: not %clang --target=powerpc64-unknown-linux-gnu -maix-small-local-dynamic-tls \
// RUN:    -fsyntax-only %s 2>&1 | FileCheck --check-prefix=CHECK-UNSUPPORTED-LINUX %s
// RUN: not %clang --target=powerpc64-unknown-aix -maix-small-local-dynamic-tls \
// RUN:    -fsyntax-only -fno-data-sections %s 2>&1 | \
// RUN:    FileCheck --check-prefix=CHECK-UNSUPPORTED-NO-DATASEC %s
// RUN: not %clang --target=powerpc64-unknown-linux-gnu -maix-small-local-dynamic-tls \
// RUN:    -fsyntax-only -fno-data-sections %s 2>&1 | \
// RUN:    FileCheck --check-prefix=CHECK-UNSUPPORTED-NO-DATASEC %s

int test(void) {
  return 0;
}

// CHECK-DEFAULT: test() #0 {
// CHECK-DEFAULT: attributes #0 = {
// CHECK-DEFAULT-NOT: {{[-+]aix-small-local-exec-tls,.*[-+]aix-small-local-dynamic-tls|[-+]aix-small-local-dynamic-tls,.*[-+]aix-small-local-exec-tls}}

// CHECK-UNSUPPORTED-AIX32: option '-maix-small-local-[exec|dynamic]-tls' cannot be specified on this target
// CHECK-UNSUPPORTED-LINUX: option '-maix-small-local-[exec|dynamic]-tls' cannot be specified on this target
// CHECK-UNSUPPORTED-NO-DATASEC: invalid argument '-maix-small-local-[exec|dynamic]-tls' only allowed with '-fdata-sections'

// CHECK-AIX_SMALL_LOCALEXEC_TLS: test() #0 {
// CHECK-AIX_SMALL_LOCALEXEC_TLS: attributes #0 = {
// CHECK-AIX_SMALL_LOCALEXEC_TLS-SAME: +aix-small-local-exec-tls

// CHECK-AIX_SMALL_LOCALDYNAMIC_TLS: test() #0 {
// CHECK-AIX_SMALL_LOCALDYNAMIC_TLS: attributes #0 = {
// CHECK-AIX_SMALL_LOCALDYNAMIC_TLS-SAME: +aix-small-local-dynamic-tls
