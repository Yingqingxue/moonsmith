///|
pub(open) trait TJsValue {
  fn to_js(Self) -> Int
}

///|
pub impl TJsValue for Int with fn to_js(self : Int) -> Int = "%identity"

///|
pub impl[T : TJsValue] TJsValue for Array[T] with fn to_js(self : Array[T]) -> Int = "%identity"

///|
fn[T : TJsValue] opt_to_js(opt : T?) -> Int {
  match opt {
    Some(value) => TJsValue::to_js(value)
    None => TJsValue::to_js(0)
  }
}

///|
pub fn make(actions? : Array[Int]) -> Int {
  opt_to_js(actions)
}
