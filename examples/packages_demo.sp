# examples/packages_demo.sp
# Demonstrates the Sapphire package/import system

import math
import strings
import collections
import datetime

println("=== Package Demo ===")
println("")

# ── math package ──────────────────────────────────────────────────────────────
println("── math ──────────────────────────────")

let start = now()

println(`primes up to 50:  #{primes_up_to(50)}`)
println(`gcd(120, 45):      #{gcd(120, 45)}`)
println(`lcm(12, 18):       #{lcm(12, 18)}`)
println(`fibonacci(15):     #{fibonacci(15)}`)
println(`factorial(10):     #{factorial(10)}`)

let data = [4, 8, 15, 16, 23, 42]
println(`sum:               #{sum(data)}`)
println(`mean:              #{mean(data)}`)
println(`min:               #{min_of(data)}`)
println(`max:               #{max_of(data)}`)
println("")

# ── strings package ────────────────────────────────────────────────────────────
println("── strings ───────────────────────────")

println(`capitalize:        #{capitalize_words("the quick brown fox")}`)
println(`palindrome check:  #{is_palindrome("racecar")}`)
println(`truncate:          #{truncate("The Sapphire Programming Language", 20, "...")}`)
println(`indent:`)
println(indent("line one\nline two\nline three", 4))
println("")

# ── collections package ────────────────────────────────────────────────────────
println("── collections ───────────────────────")

let nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

let groups = chunk(nums, 3)
println(`chunks of 3: #{groups}`)

let freq = frequencies(["apple", "banana", "apple", "cherry", "banana", "apple"])
println(`fruit frequencies: #{freq}`)

let mixed = [1, nil, 2, nil, 3]
let cleaned = compact(mixed)
println(`compact: #{cleaned}`)

let grp = group_by(nums, { |n| n % 2 == 0 ? "even" : "odd" })
println(`grouped by parity: #{grp}`)
println("")

# ── datetime package ───────────────────────────────────────────────────────────
println("── datetime ──────────────────────────")

let elapsed = elapsed_since(start)
println(`script ran in: #{elapsed}s`)
println(`formatted: #{format_duration(3723)}`)
println("")

println("=== Done! ===")
