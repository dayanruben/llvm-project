//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// <algorithm>

// UNSUPPORTED: c++03, c++11, c++14, c++17

// template<input_iterator I1, sentinel_for<I1> S1, input_iterator I2, sentinel_for<I2> S2>
//   requires indirectly_swappable<I1, I2>
//   constexpr ranges::swap_ranges_result<I1, I2>
//     ranges::swap_ranges(I1 first1, S1 last1, I2 first2, S2 last2);
// template<input_range R1, input_range R2>
//   requires indirectly_swappable<iterator_t<R1>, iterator_t<R2>>
//   constexpr ranges::swap_ranges_result<borrowed_iterator_t<R1>, borrowed_iterator_t<R2>>
//     ranges::swap_ranges(R1&& r1, R2&& r2);

#include <algorithm>
#include <array>
#include <cassert>
#include <ranges>
#include <vector>

#include <cstdio>

#include "test_iterators.h"
#include "type_algorithms.h"

template <class Iter1, class Iter2>
TEST_CONSTEXPR_CXX20 void test_iterators() {
  using Expected = std::ranges::swap_ranges_result<Iter1, Iter2>;
  { // Basic test case: swapping three elements between two arrays
    int a[3] = {1, 2, 3};
    int b[3] = {4, 5, 6};
    std::same_as<Expected> auto r =
        std::ranges::swap_ranges(Iter1(a), sentinel_wrapper(Iter1(a + 3)), Iter2(b), sentinel_wrapper(Iter2(b + 3)));
    assert(base(r.in1) == a + 3);
    assert(base(r.in2) == b + 3);
    assert(std::ranges::equal(a, std::array{4, 5, 6}));
    assert(std::ranges::equal(b, std::array{1, 2, 3}));
  }
  { // Large-scale test: swapping 100 elements between two different containers
    const int N = 100;
    std::array<int, N> a;
    std::vector<int> b(N + 2, 42);
    b.front() = 1;
    b.back()  = -1;
    for (int i = 0; i < N; ++i)
      a[i] = i * i + 1;
    std::same_as<Expected> auto r = std::ranges::swap_ranges(
        Iter1(a.data()),
        sentinel_wrapper(Iter1(a.data() + N)),
        Iter2(b.data() + 1),
        sentinel_wrapper(Iter2(b.data() + b.size())));
    assert(base(r.in1) == a.data() + N);
    assert(base(r.in2) == b.data() + N + 1);
    assert(b.front() == 1); // Ensure that the unswapped portion remains unchanged
    assert(b.back() == -1);
    for (int i = 0; i < N; ++i) {
      assert(a[i] == 42);
      assert(b[i + 1] == i * i + 1);
    }
  }
}

template <std::size_t N>
constexpr void test_vector_bool() {
  { // Test swap_ranges() with aligned bytes
    std::vector<bool> f(N, false), t(N, true);
    std::ranges::swap_ranges(f, t);
    assert(std::all_of(f.begin(), f.end(), [](bool b) { return b; }));
    assert(std::all_of(t.begin(), t.end(), [](bool b) { return !b; }));
  }
  { // Test swap_ranges() with unaligned bytes
    std::vector<bool> f(N, false), t(N + 8, true);
    std::ranges::swap_ranges(f.begin(), f.end(), t.begin() + 4, t.end() - 4);
    assert(std::all_of(f.begin(), f.end(), [](bool b) { return b; }));
    assert(std::all_of(t.begin() + 4, t.end() - 4, [](bool b) { return !b; }));
  }
}

constexpr bool test() {
  { // Validate swapping ranges directly
    std::array r1 = {1, 2, 3};
    std::array r2 = {4, 5, 6};

    std::same_as<std::ranges::in_in_result<std::array<int, 3>::iterator, std::array<int, 3>::iterator>> auto r =
        std::ranges::swap_ranges(r1, r2);
    assert(r.in1 == r1.end());
    assert(r.in2 == r2.end());
    assert((r1 == std::array{4, 5, 6}));
    assert((r2 == std::array{1, 2, 3}));
  }

  { // Validate swapping ranges using iterator and sentinels
    int i[3]                      = {1, 2, 3};
    int j[3]                      = {4, 5, 6};
    using It                      = cpp17_input_iterator<int*>;
    using Sent                    = sentinel_wrapper<It>;
    using Expected                = std::ranges::swap_ranges_result<It, It>;
    std::same_as<Expected> auto r = std::ranges::swap_ranges(It(i), Sent(It(i + 3)), It(j), Sent(It(j + 3)));
    assert(base(r.in1) == i + 3);
    assert(base(r.in2) == j + 3);
    assert(std::ranges::equal(i, std::array{4, 5, 6}));
    assert(std::ranges::equal(j, std::array{1, 2, 3}));
  }

  { // Validate swapping ranges of different lengths
    using Expected                = std::ranges::swap_ranges_result<int*, int*>;
    int i[3]                      = {1, 2, 3};
    int j[1]                      = {4};
    std::same_as<Expected> auto r = std::ranges::swap_ranges(i, i + 3, j, j + 1);
    assert(r.in1 == i + 1);
    assert(r.in2 == j + 1);
    assert(std::ranges::equal(i, std::array{4, 2, 3}));
    assert(std::ranges::equal(j, std::array{1}));
    std::same_as<Expected> auto r2 = std::ranges::swap_ranges(i, j);
    assert(r2.in1 == i + 1);
    assert(r2.in2 == j + 1);
    assert(std::ranges::equal(i, std::array{1, 2, 3}));
    assert(std::ranges::equal(j, std::array{4}));
    std::same_as<Expected> auto r3 = std::ranges::swap_ranges(j, j + 1, i, i + 3);
    assert(r3.in1 == j + 1);
    assert(r3.in2 == i + 1);
    assert(std::ranges::equal(i, std::array{4, 2, 3}));
    assert(std::ranges::equal(j, std::array{1}));
    std::same_as<Expected> auto r4 = std::ranges::swap_ranges(j, i);
    assert(r4.in1 == j + 1);
    assert(r4.in2 == i + 1);
    assert(std::ranges::equal(i, std::array{1, 2, 3}));
    assert(std::ranges::equal(j, std::array{4}));
  }

  { // Validate swapping when one or both are borrowed input ranges (views)
    {
      int r1[] = {1, 2, 3};
      int r2[] = {4, 5, 6};
      std::ranges::swap_ranges(std::views::all(r1), r2);
      assert(std::ranges::equal(r1, std::array{4, 5, 6}));
      assert(std::ranges::equal(r2, std::array{1, 2, 3}));
    }
    {
      int r1[] = {1, 2, 3};
      int r2[] = {4, 5, 6};
      std::ranges::swap_ranges(r1, std::views::all(r2));
      assert(std::ranges::equal(r1, std::array{4, 5, 6}));
      assert(std::ranges::equal(r2, std::array{1, 2, 3}));
    }
    {
      int r1[] = {1, 2, 3};
      int r2[] = {4, 5, 6};
      std::ranges::swap_ranges(std::views::all(r1), std::views::all(r2));
      assert(std::ranges::equal(r1, std::array{4, 5, 6}));
      assert(std::ranges::equal(r2, std::array{1, 2, 3}));
    }
  }

  { // Validate swapping involving rvalue ranges
    {
      using Expected       = std::ranges::swap_ranges_result<std::array<int, 3>::iterator, std::ranges::dangling>;
      std::array<int, 3> r = {1, 2, 3};
      std::same_as<Expected> auto a = std::ranges::swap_ranges(r, std::array{4, 5, 6});
      assert((r == std::array{4, 5, 6}));
      assert(a.in1 == r.begin() + 3);
    }
    {
      std::array<int, 3> r = {1, 2, 3};
      using Expected       = std::ranges::swap_ranges_result<std::ranges::dangling, std::array<int, 3>::iterator>;
      std::same_as<Expected> auto b = std::ranges::swap_ranges(std::array{4, 5, 6}, r);
      assert((r == std::array{4, 5, 6}));
      assert(b.in2 == r.begin() + 3);
    }
  }

  types::for_each(types::cpp20_input_iterator_list<int*>(), []<class Iter1>() {
    types::for_each(types::cpp20_input_iterator_list<int*>(), []<class Iter2>() {
      test_iterators<Iter1, Iter2>();
      test_iterators<ProxyIterator<Iter1>, ProxyIterator<Iter2>>();
    });
  });

  { // Test vector<bool>::iterator optimization
    test_vector_bool<8>();
    test_vector_bool<19>();
    test_vector_bool<32>();
    test_vector_bool<49>();
    test_vector_bool<64>();
    test_vector_bool<199>();
    test_vector_bool<256>();
  }
  return true;
}

static_assert(std::same_as<std::ranges::swap_ranges_result<int, char>, std::ranges::in_in_result<int, char>>);

int main(int, char**) {
  test();
  static_assert(test());

  return 0;
}
