# stdlib/math.sp — Extended math utilities for Sapphire

fn gcd(a, b) {
  while b != 0 {
    let t = b
    b = a % b
    a = t
  }
  return a
}

fn lcm(a, b) {
  return (a * b) / gcd(a, b)
}

fn is_prime(n) {
  if n < 2 { return false }
  if n == 2 { return true }
  if n % 2 == 0 { return false }
  let i = 3
  while i * i <= n {
    if n % i == 0 { return false }
    i += 2
  }
  return true
}

fn primes_up_to(n) {
  let result = []
  for i in 2..n {
    if is_prime(i) { result.push(i) }
  }
  return result
}

fn fibonacci(n) {
  if n <= 1 { return n }
  let a = 0
  let b = 1
  let i = 2
  while i <= n {
    let c = a + b
    a = b
    b = c
    i += 1
  }
  return b
}

fn factorial(n) {
  if n <= 1 { return 1 }
  return n * factorial(n - 1)
}

fn clamp(val, lo, hi) {
  if val < lo { return lo }
  if val > hi { return hi }
  return val
}

fn lerp(a, b, t) {
  return a + (b - a) * t
}

fn sum(arr) {
  return arr.reduce({ |acc, n| acc + n }, 0)
}

fn mean(arr) {
  if arr.length == 0 { return 0 }
  return sum(arr) / arr.length
}

fn max_of(arr) {
  return arr.reduce({ |acc, n| n > acc ? n : acc }, arr[0])
}

fn min_of(arr) {
  return arr.reduce({ |acc, n| n < acc ? n : acc }, arr[0])
}
