# examples/fizzbuzz.sp

fn fizzbuzz(n) {
  for i in 1..n {
    match true {
      i % 15 == 0 => println("FizzBuzz")
      i % 3 == 0  => println("Fizz")
      i % 5 == 0  => println("Buzz")
      _           => println(i)
    }
  }
}

fizzbuzz(20)
