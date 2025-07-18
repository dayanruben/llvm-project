//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// UNSUPPORTED: c++03, c++11, c++14

// Ensure that passing a nullptr to polymorphic_allocator is diagnosed

#include <memory_resource>

void test() {
  std::pmr::polymorphic_allocator<int> alloc(nullptr); // expected-warning {{null passed}}
}
