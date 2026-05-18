# examples/test_demo.sp — Shows the built-in test framework
# Run: sapphire examples/test_demo.sp

import test
import math

describe("math module", fn() {
  it("gcd computes correctly", fn() {
    assert_eq(gcd(48, 18), 6)
    assert_eq(gcd(100, 75), 25)
  })

  it("identifies primes", fn() {
    assert_true(is_prime(2))
    assert_true(is_prime(17))
    assert_false(is_prime(1))
    assert_false(is_prime(20))
  })

  it("computes fibonacci", fn() {
    assert_eq(fibonacci(0), 0)
    assert_eq(fibonacci(1), 1)
    assert_eq(fibonacci(10), 55)
  })

  it("computes factorial", fn() {
    assert_eq(factorial(5), 120)
    assert_eq(factorial(10), 3628800)
  })

  it("stats helpers", fn() {
    assert_eq(mean([1, 2, 3, 4, 5]), 3)
    assert_eq(sum([1, 2, 3]), 6)
    assert_eq(min_of([5, 3, 9, 1]), 1)
    assert_eq(max_of([5, 3, 9, 1]), 9)
  })
})

describe("arrays", fn() {
  it("maps elements", fn() {
    let doubled = [1, 2, 3].map({ |n| n * 2 })
    assert_eq(doubled.length, 3)
    assert_eq(doubled[0], 2)
  })

  it("filters elements", fn() {
    let evens = [1, 2, 3, 4, 5, 6].filter({ |n| n % 2 == 0 })
    assert_eq(evens.length, 3)
  })

  it("reduces to sum", fn() {
    let total = [1, 2, 3, 4, 5].reduce({ |acc, n| acc + n }, 0)
    assert_eq(total, 15)
  })

  it("sorts correctly", fn() {
    let s = [5, 2, 8, 1, 9, 3].sort
    assert_eq(s[0], 1)
    assert_eq(s[5], 9)
  })
})

describe("strings", fn() {
  it("reverses", fn() {
    assert_eq("hello".reverse, "olleh")
  })

  it("prefix/suffix checks", fn() {
    assert_true("hello world".starts_with?("hello"))
    assert_true("hello world".ends_with?("world"))
  })

  it("splits and joins", fn() {
    let parts = "a,b,c".split(",")
    assert_eq(parts.length, 3)
    assert_eq(parts.join("-"), "a-b-c")
  })

  it("case conversion", fn() {
    assert_eq("hello".upcase, "HELLO")
    assert_eq("WORLD".downcase, "world")
  })
})

describe("control flow", fn() {
  it("ternary works", fn() {
    let r = 10 > 5 ? "big" : "small"
    assert_eq(r, "big")
  })

  it("try/catch works", fn() {
    let caught = false
    try {
      raise "oops"
    } catch (e) {
      caught = true
    }
    assert_true(caught)
  })

  it("for loop sums range", fn() {
    let total = 0
    for i in 1..5 {
      total += i
    }
    assert_eq(total, 15)
  })
})

test_summary()
