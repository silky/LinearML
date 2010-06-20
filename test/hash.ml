
module HashTableService:sig

  type msg('a,'b,'c) = 
    | Add('a,'b)
    | Del('a)
    | Get(service('c,'b),'c,'a)

  type t('a,'b,'c) = service(msg('a,'b,'c))
  
  val create: (int,int) -> t('a,'b)

end = struct

  let handler(ht,msg) = 
    match msg with
    | Add(x,y) -> HashTable.add(ht,x,y)
    | Del(x) -> HashTable.remove(ht,x)
    | Get(res,next,x) -> 
	ht, v = HashTable.get x ;
	send(res,next,v) ;
	ht

  let create(size,bsize) = 
    ht = HashTable.create(size) ;
    service(bsize,handler,ht)
end

module HashTableServiceTest: sig

  val main: array(string) -> int
end = struct

  module Ht = HashTableService

  let receiver(v) =

  let main(_) = 
    hts = Ht.create(1024,1024) ;
    send(hts, Add(2,3)) ;
    send(hts, Get(2),next,env)

end


module HashTable: sig

  type ('a, 'b) t = {
      hash: ('a -> int) ;
      table: 'b shared array ;
    }

  val find: ('a,'b) t -> 'a -> 'b shared

end = struct

  let find t x = 
    let idx = t.hash x % Array.size t.table in
    Array.get_shared t.table idx
end

module HashTableController: sig
  module HTA = HashTableProc

  type ('a, 'b) t = ('a, 'b) HTA.t array
  
  val make: unit -> ('a, 'b) t

end = struct

  let query t msg up = 
    match msg with
    | Find (x, res) -> send t[index x] (Find x) ; t
    | Merge (x, y, res) -> 
	let t, pkg_id = make_pkg_id t in
	send merger up ;
	send t[index x] (Find_part (merger, x)) ;
	send t[index y] (Find_part (merger, y)) ;
	t

  let answers t msg = 
    match msg with
    | Found_part (merger, x) ->
	let t, is_done = store pkg_id x in
	if is_done
	then (send merger x ; t)
	else store pkg_id x
    | Merging_done (merger, x) -> send up x
end

module Dangerous: sig
end = struct

  let ping pong (n, stdout) =
    if n = 0
    then stdout
    else 
      let stdout = print sdout "ping" in 
      send pong (n-1, stdout)

  let main = 
    let ping = make ping 10 in
    

end

module Test: sig
end = struct

  let query t down up = 
    let down, msg = read down in
    match msg with
    | Find (x, res) -> 
	let write t[index x] (Find x) ; t
    | Merge (x, y, res) -> 
	let c1, c2 = join() in
	send (Find_part (c1, x)) ;
	send (Find_part (c2, y))
	
  let make msg = 
    let senders = Array.init make_fifo 10 in
    let receivers = Array.init make_fifo 10 in
    let workers = Array.init make_worker 10 in
    ()

end

module Actor: sig
end = struct

  let rec loop f st recv = 
    let recv, msg = Fifo.read recv in
    let st = f st in
    loop f st recv

  let make_loop { f, st, recv } = loop f st recv

  let make f state = 
    let send, recv = fifo() in
    spawn make_loop { f ; state ;  recv } ;
    recv 

end
