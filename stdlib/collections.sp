# stdlib/collections.sp — Collection utilities for Sapphire

fn flatten(arr) {
  return arr.flatten
}

fn zip(a, b) {
  return Array.zip(a, b)
}

fn chunk(arr, size) {
  let result = []
  let i = 0
  while i < arr.length {
    result.push(arr.slice(i, size))
    i += size
  }
  return result
}

fn take(arr, n) {
  return arr.slice(0, n)
}

fn drop(arr, n) {
  return arr.slice(n, arr.length - n)
}

fn count_by(arr, fn_pred) {
  return arr.filter(fn_pred).length
}

fn group_by(arr, key_fn) {
  let result = make_hash()
  arr.each({ |item|
    let k = key_fn(item)
    let ks = str(k)
    if result.has?(ks) {
      result[ks].push(item)
    } else {
      result[ks] = [item]
    }
  })
  return result
}

fn unique(arr) {
  return arr.uniq
}

fn frequencies(arr) {
  let result = make_hash()
  arr.each({ |item|
    let k = str(item)
    if result.has?(k) {
      result[k] += 1
    } else {
      result[k] = 1
    }
  })
  return result
}

fn compact(arr) {
  return arr.filter({ |x| x != nil })
}

fn first_n(arr, n) {
  return arr.slice(0, n)
}

fn last_n(arr, n) {
  let start = arr.length - n
  if start < 0 { return arr }
  return arr.slice(start, n)
}

fn sum(arr) {
  return arr.reduce({ |acc, n| acc + n }, 0)
}

fn product(arr) {
  return arr.reduce({ |acc, n| acc * n }, 1)
}
