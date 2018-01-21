open Cil
open Feature
module E = Errormsg

let currentFunc : fundec ref = ref (emptyFunction "@dummy")
                                   
let todo () = E.s (E.error "todo")
let error () = E.s (E.error "impossible")

let two = integer 2
let makeArray t = TArray(t, Some two, [])
let mkArraySelect vi e : lval = (Var vi, Index(e, NoOffset))

let dummyLocation = {line = 0; file = ""; byte = 0;}

let dummyMem : varinfo =
  let x =
    makeGlobalVar "dummy_mem" (TArray(charType, Some(integer 1024), [])) in
  x.vstorage <- Static; x

let dummyMem' : exp = mkAddrOrStartOf (var dummyMem)
  

let dummyFun : varinfo =
  makeVarinfo false "dummy_f" (TFun(voidType, Some [], false ,[]))

let dummyFunDecl : fundec =
  let x = emptyFunction "dummy_f" in
  x.svar.vstorage <- Static; x


let addrOfType t : typ =
  typeOf(mkAddrOrStartOf (var (makeVarinfo false "" t)))

let addrOfExp e : typ = addrOfType (typeOf e)
  

let condExp = one

let rec doStmt s cond =
  match s.skind with
  | Instr (x) ->
     s.skind <- Instr(List.flatten (List.map (fun e -> doInstr e cond) x))
  | Return (eop, loc) -> ()
  | Goto (sr, loc) ->  ()
  | ComputedGoto (e, loc) -> ()
  | Break (_) ->  ()
  | Continue (_) -> ()
  | If (c, t, e, loc) -> ()
  | Switch (_, _, _, _) ->  ()
  | Loop (b, loc, x, y) ->  ()
  | Block (b) ->  ()
  | TryFinally (_, _, _) ->  ()
  | TryExcept (_, _, _, _) ->  ()
             
and doIf cond t e loc =
  todo ()
      
and doInstr t cond =
  match t with
  | Set (l, (Lval(Mem(e), off) as r) , loc) ->
     let s = makeTempVar !currentFunc (makeArray (addrOfExp r)) in
     let s' = makeTempVar !currentFunc (makeArray (addrOfExp r)) in
     [Set(mkArraySelect s zero, dummyMem', loc)
     ; Set(mkArraySelect s one, mkAddrOrStartOf (Mem(e), off), loc)
     ; Set(mkArraySelect s' zero, dummyMem', loc)
     ; Set(mkArraySelect  s' one, mkAddrOrStartOf l, loc)
     ; Set(mkMem (Lval(mkArraySelect s' one)) NoOffset
         , Lval(mkMem (Lval(mkArraySelect s one)) NoOffset)
         , loc)]
  | Set (l, e, loc) ->
     let s = makeTempVar !currentFunc (makeArray (addrOfExp e)) in
     [Set(mkArraySelect s zero, dummyMem', loc)
     ; Set(mkArraySelect s one, mkAddrOrStartOf l, loc)
     ; Set((mkMem (Lval(mkArraySelect s condExp)) NoOffset), e, loc)]
  | Call (l, e, es, loc) ->
     let s = makeTempVar !currentFunc (makeArray (addrOfExp e)) in
     let r = match l with
       | Some l ->
          let (t, _, _, _) = splitFunctionType (typeOf e) in
          let s' = makeTempVar !currentFunc (makeArray (addrOfType t)) in
          [Set(mkArraySelect s' zero, dummyMem', loc)
          ; Set(mkArraySelect s' one, mkAddrOrStartOf l, loc)
          ; Set(mkArraySelect s zero, Lval(var dummyFun), loc)
          ; Set(mkArraySelect s one, e, loc)
          ; Call(Some (mkMem (Lval(mkArraySelect s' condExp)) NoOffset)
               , Lval(mkArraySelect s condExp)
               , es
               , loc)]
       | None -> 
          [Set(mkArraySelect s zero, Lval(var dummyFun), loc)
          ; Set(mkArraySelect s one, e, loc)
          ; Call(None, Lval((mkArraySelect s condExp)), es, loc)]
     in
     r
  | Asm (_, _, _, _, _, _) -> todo ()


and doStmts t cond =
  match t with
  | [] -> ()
  | x :: rests ->
     doStmt x cond; 
     doStmts rests cond


and doBlock t cond =
  doStmts t.bstmts cond
            
  
let scanFunc f =
  currentFunc := f;
  doBlock f.sbody []
    
    
let feature = 
  { fd_name = "flatten";
    fd_enabled = false;
    fd_description = "flatten for fun!" ;
    fd_extraopt = [];
    fd_doit = (function (f : file) -> 
                         let _ = iterGlobals f (fun glob ->
                                     match glob with
                                     | GFun (fd,_) -> scanFunc fd
                                     | _ -> ()) in
                         f.globals <- GFun(dummyFunDecl, dummyLocation) :: f.globals;
                         f.globals <- GVar(dummyMem , {init=None}, dummyLocation) :: f.globals;
              );
    fd_post_check = true;
  }

let () = Feature.register feature
