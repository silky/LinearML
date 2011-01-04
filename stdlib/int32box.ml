
module Int32Box = struct

  type t = { value: int32 }

  val make: int32 -> t
  let make n = { value = n }

  val get: t obs -> int32
  let get t = 
    match t with 
    | { _ ; value = n } -> n

  val release: t -> unit
  let release t = free t
end