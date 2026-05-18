# examples/showcase.sp
# Comprehensive tour of Sapphire features

println("=== Sapphire Language Showcase ===")
println("")

# ── Variables ─────────────────────────────────────────────────────────────────
println("── Variables & Types ─────")
let name = "Sapphire"
const VERSION = "0.4.0"
let count = 42
let pi = 3.14159
let active = true
let nothing = nil

println(`name    = #{name}`)
println(`version = #{VERSION}`)
println(`count   = #{count}`)
println(`pi      = #{pi}`)
println(`active  = #{active}`)
println(`nothing = #{nothing}`)
println("")

# ── Arithmetic ────────────────────────────────────────────────────────────────
println("── Arithmetic ────────────")
println(`2 ** 10 = #{2 ** 10}`)
println(`17 % 5  = #{17 % 5}`)
println(`10 / 3  = #{10 / 3}`)
println(`sqrt(2) = #{Math.sqrt(2)}`)
println("")

# ── Strings ───────────────────────────────────────────────────────────────────
println("── Strings ───────────────")
let greeting = "Hello, World!"
println(`length    = #{greeting.length}`)
println(`upcase    = #{greeting.upcase}`)
println(`reverse   = #{greeting.reverse}`)
println(`includes? = #{greeting.includes?("World")}`)
let parts = greeting.split(", ")
println(`split     = #{parts[0]} / #{parts[1]}`)
println("")

# ── Arrays ────────────────────────────────────────────────────────────────────
println("── Arrays ────────────────")
let nums = [10, 3, 7, 1, 9, 4, 6, 2, 8, 5]
println(`original = #{nums}`)

let doubled = nums.map({ |n| n * 2 })
println(`doubled  = #{doubled}`)

let evens = nums.filter({ |n| n % 2 == 0 })
println(`evens    = #{evens}`)

let total = nums.reduce({ |acc, n| acc + n }, 0)
println(`sum      = #{total}`)

let sorted = nums.sort
println(`sorted   = #{sorted}`)

let found = nums.find({ |n| n > 7 })
println(`first>7  = #{found}`)

let all_pos = nums.all?({ |n| n > 0 })
println(`all > 0? = #{all_pos}`)
println("")

# ── Hashes ────────────────────────────────────────────────────────────────────
println("── Hashes ────────────────")
let person = { name: "Alice", age: 30, city: "Berlin" }
println(`name = #{person["name"]}`)
println(`age  = #{person["age"]}`)
person["job"] = "Engineer"
println(`keys = #{person.keys}`)
println("")

# ── Control Flow ──────────────────────────────────────────────────────────────
println("── Control Flow ──────────")
let x = 42
if x > 100 {
  println("big")
} elif x > 50 {
  println("medium")
} elif x > 20 {
  println("small-ish")
} else {
  println("tiny")
}

# Ternary
let label = x > 50 ? "large" : "small"
println(`ternary: #{label}`)

# While + break
let i = 0
let sum = 0
while true {
  if i > 9 { break }
  sum += i
  i += 1
}
println(`sum 0..9 = #{sum}`)

# For + range
let squares = []
for n in 1..5 {
  squares.push(n * n)
}
println(`squares = #{squares}`)
println("")

# ── Match ─────────────────────────────────────────────────────────────────────
println("── Pattern Matching ──────")
let day = "Monday"
match day {
  "Saturday" => println("Weekend!")
  "Sunday"   => println("Weekend!")
  "Monday"   => println("Back to work...")
  _          => println(`${day} is a weekday`)
}

let score = 87
match true {
  score >= 90 => println("Grade: A")
  score >= 80 => println("Grade: B")
  score >= 70 => println("Grade: C")
  _           => println("Grade: D or below")
}
println("")

# ── Functions ─────────────────────────────────────────────────────────────────
println("── Functions ─────────────")

fn greet(name, greeting = "Hello") {
  return `#{greeting}, #{name}!`
}
println(greet("Bob"))
println(greet("Alice", greeting: "Hi"))

fn factorial(n) {
  if n <= 1 { return 1 }
  return n * factorial(n - 1)
}
println(`10! = #{factorial(10)}`)

fn fib(n) {
  if n <= 1 { return n }
  return fib(n - 1) + fib(n - 2)
}
println(`fib(10) = #{fib(10)}`)

# Variadic
fn sum_all(*nums) {
  return nums.reduce({ |acc, n| acc + n }, 0)
}
println(`sum(1..5) = #{sum_all(1, 2, 3, 4, 5)}`)

# Lambda / closures
fn make_adder(n) {
  return { |x| x + n }
}
let add10 = make_adder(10)
println(`add10(5) = #{add10(5)}`)
println("")

# ── Classes & OOP ─────────────────────────────────────────────────────────────
println("── Classes & OOP ─────────")

class Animal {
  fn init(name, sound) {
    self.name = name
    self.sound = sound
  }
  fn speak() {
    return `#{self.name} says: #{self.sound}!`
  }
  fn to_string() {
    return `<Animal: #{self.name}>`
  }
}

class Dog < Animal {
  fn init(name) {
    self.name = name
    self.sound = "Woof"
    self.tricks = []
  }
  fn learn(trick) {
    self.tricks.push(trick)
  }
  fn perform() {
    if self.tricks.empty? {
      return `#{self.name} doesn't know any tricks yet.`
    }
    return `#{self.name} knows: #{self.tricks.join(", ")}`
  }
}

let cat = new Animal("Whiskers", "Meow")
println(cat.speak())

let dog = new Dog("Rex")
println(dog.speak())
dog.learn("sit")
dog.learn("shake")
dog.learn("roll over")
println(dog.perform())
println("")

# ── Try / Catch ───────────────────────────────────────────────────────────────
println("── Error Handling ────────")

fn safe_divide(a, b) {
  try {
    if b == 0 { raise "Cannot divide by zero!" }
    return a / b
  } catch (err) {
    return `Error: #{err}`
  }
}

println(safe_divide(10, 2))
println(safe_divide(10, 0))

try {
  let arr = [1, 2, 3]
  println(arr.index_of(99))
} catch (e) {
  println(`caught: #{e}`)
} finally {
  println("(finally block ran)")
}
println("")

# ── Template Strings ──────────────────────────────────────────────────────────
println("── Template Strings ──────")
let a = 5
let b = 7
println(`#{a} + #{b} = #{a + b}`)
println(`#{a} ** 2 = #{a ** 2}`)
println(`Is #{a} even? #{a % 2 == 0 ? "yes" : "no"}`)
println("")

# ── Typeof ────────────────────────────────────────────────────────────────────
println("── Typeof ────────────────")
println(`typeof 42      = #{typeof 42}`)
println(`typeof 3.14    = #{typeof 3.14}`)
println(`typeof "hello" = #{typeof "hello"}`)
println(`typeof true    = #{typeof true}`)
println(`typeof nil     = #{typeof nil}`)
println(`typeof []      = #{typeof []}`)
println(`typeof {}      = #{typeof {name: "x"}}`)
println("")

println("=== Done! ===")
