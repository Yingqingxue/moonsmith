///|
/// A small, first-party reproduction of the native stack-overflow behavior
/// reported upstream in moonbitlang/moon#2228. It deliberately keeps one
/// frame per recursive call; run only in a bounded child process.
fn deep(n : Int) -> Int {
  if n <= 0 {
    0
  } else {
    1 + deep(n - 1)
  }
}

///|
fn main {
  println("before-deep-recursion")
  println(deep(1_000_000))
}
