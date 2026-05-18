# stdlib/test.sp — Minimalist test framework for Sapphire
# Usage:
#   import test
#
#   describe("MyModule", fn() {
#     it("adds numbers", fn() {
#       assert_eq(1 + 1, 2)
#     })
#   })
#   test_summary()

let _test_pass = 0
let _test_fail = 0

fn describe(name, suite_fn) {
  println(`\n#{name}`)
  suite_fn()
}

fn it(label, test_fn) {
  try {
    test_fn()
    _test_pass += 1
    println(`  PASS: #{label}`)
  } catch (err) {
    _test_fail += 1
    println(`  FAIL: #{label}`)
    println(`    => #{err}`)
  }
}

fn assert_eq(actual, expected) {
  if actual != expected {
    raise `assert_eq failed: expected #{expected}, got #{actual}`
  }
}

fn assert_true(val) {
  if val != true {
    raise `assert_true failed: got #{val}`
  }
}

fn assert_false(val) {
  if val != false {
    raise `assert_false failed: got #{val}`
  }
}

fn assert_nil(val) {
  if val != nil {
    raise `assert_nil failed: got #{val}`
  }
}

fn test_summary() {
  let total = _test_pass + _test_fail
  println("\n-------------------------------------")
  if _test_fail == 0 {
    println(`All #{total} tests passed!`)
  } else {
    println(`Tests: #{total}  Passed: #{_test_pass}  Failed: #{_test_fail}`)
  }
}
