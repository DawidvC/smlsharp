structure TyReduce =
struct
local
  structure T = Types
  structure TU = TypesBasics
  structure P = TyPrinters
  type ty = T.ty
  type varInfo = T.varInfo
  type longsymbol = Symbol.longsymbol
  type btv = BoundTypeVarID.id
  fun bug s = Bug.Bug ("TyReduce: " ^ s)
in
  type btvMap = ty BoundTypeVarID.Map.map
  val emptyBtvMap = BoundTypeVarID.Map.empty : btvMap

  fun evalBtv (btvMap:btvMap) (btv:btv) : ty =
       case BoundTypeVarID.Map.find(btvMap, btv) of
         NONE => T.BOUNDVARty btv
       | SOME ty => TyAlphaRename.copyTy TyAlphaRename.emptyBtvMap ty

  val foo = evalBtv
  fun evalSingletonTy (btvMap:btvMap) (singletonTy:T.singletonTy) : T.singletonTy =
      case singletonTy of
        T.INSTCODEty
          {
           oprimId,
           longsymbol,
           keyTyList : ty list,
           match : T.overloadMatch,
           instMap : T.overloadMatch OPrimInstMap.map
          } =>
        T.INSTCODEty
          {
           oprimId=oprimId,
           longsymbol=longsymbol,
           keyTyList = map (evalTy btvMap) keyTyList,
           match = evalOverloadMatch btvMap match,
           instMap = OPrimInstMap.map (evalOverloadMatch btvMap) instMap
          }
      | T.INDEXty (string, ty) => T.INDEXty (string, evalTy btvMap ty)
      | T.TAGty ty => T.TAGty (evalTy btvMap ty)
      | T.SIZEty ty => T.SIZEty (evalTy btvMap ty)
      | T.TYPEty ty => T.TYPEty (evalTy btvMap ty)
      | T.REIFYty ty => T.REIFYty (evalTy btvMap ty)
  and evalOverloadMatch (btvMap:btvMap) (overloadMatch:T.overloadMatch) 
      : T.overloadMatch =
      case overloadMatch  of
        T.OVERLOAD_EXVAR {exVarInfo, instTyList} =>
        T.OVERLOAD_EXVAR
          {exVarInfo = evalExVarInfo btvMap exVarInfo,
           instTyList = map (evalTy btvMap) instTyList
          }
       | T.OVERLOAD_PRIM {primInfo, instTyList} =>
         T.OVERLOAD_PRIM
           {
            primInfo = evalPrimInfo btvMap primInfo,
            instTyList = map (evalTy btvMap) instTyList
           }
       | T.OVERLOAD_CASE (ty, map:T.overloadMatch TypID.Map.map) =>
         T.OVERLOAD_CASE
           (evalTy btvMap ty,
            TypID.Map.map (evalOverloadMatch btvMap) map
           )
  and evalExVarInfo (btvMap:btvMap) {path:longsymbol,ty:ty} : T.exVarInfo =
      {path=path, ty=evalTy btvMap ty}
  and evalPrimInfo (btvMap:btvMap) ({primitive, ty}:T.primInfo) : T.primInfo =
      {primitive=primitive, ty=evalTy btvMap ty}
  and evalOprimInfo (btvMap:btvMap) ({ty, path, id}:T.oprimInfo) : T.oprimInfo =
      {ty=evalTy btvMap ty, path=path,id=id}
  and evalConInfo (btvMap:btvMap) ({path, ty, id}:T.conInfo) : T.conInfo =
      {path=path, ty=evalTy btvMap ty, id=id}
  and evalExnInfo (btvMap:btvMap) ({path, ty, id}:T.exnInfo) : T.exnInfo =
      {path=path, ty=evalTy btvMap ty, id=id}
  and evalExExnInfo (btvMap:btvMap) ({path, ty}:T.exExnInfo) : T.exExnInfo =
      {path=path, ty=evalTy btvMap ty}
  and evalTy (btvMap:btvMap) (ty:ty) : ty =
      case TU.derefTy ty of
        T.SINGLETONty singletonTy =>
        T.SINGLETONty (evalSingletonTy btvMap singletonTy)
      | T.BACKENDty backendTy =>
        raise Bug.Bug "evalTy: BACKENDty"
      | T.ERRORty => 
        ty
      | T.DUMMYty (id, kind) =>
        T.DUMMYty (id, evalKind btvMap kind)
      | T.TYVARty _ => raise bug "TYVARty in Optimize"
      | T.BOUNDVARty btv => 
        evalBtv btvMap btv
      | T.FUNMty (tyList, ty) =>
        T.FUNMty (map (evalTy btvMap) tyList, evalTy btvMap ty)
      | T.RECORDty (fields:ty RecordLabel.Map.map) =>
        T.RECORDty (RecordLabel.Map.map (evalTy btvMap) fields)
      | T.CONSTRUCTty
          {
           tyCon =
           {id : T.typId,
            longsymbol : longsymbol,
            iseq : bool,
            arity : int,
            runtimeTy : BuiltinTypeNames.bty,
            conSet,
            conIDSet,
            extraArgs : ty list,
            dtyKind : T.dtyKind
           },
           args : ty list
          } =>
        T.CONSTRUCTty
          {
           tyCon =
           {id = id,
            longsymbol = longsymbol,
            iseq = iseq,
            arity = arity,
            runtimeTy = runtimeTy,
            conSet = conSet,
            conIDSet = conIDSet,
            extraArgs = map (evalTy btvMap) extraArgs,
            dtyKind = evalDtyKind btvMap dtyKind
           },
           args = map (evalTy btvMap) args
          }
      | T.POLYty
          {
           boundtvars : T.btvEnv,
           constraints : T.constraint list,
           body : ty
          } =>
        let
          val boundtvars = evalBtvEnv btvMap boundtvars
          val constraints = List.map
                                (fn c =>
                                    case c of T.JOIN {res, args = (arg1, arg2), loc} =>
                                      T.JOIN
                                          {res = evalTy btvMap res,
                                           args = (evalTy btvMap arg1,
                                                   evalTy btvMap arg2), loc=loc})
                                constraints
        in
          T.POLYty
            {
             boundtvars = boundtvars,
             constraints = constraints,
             body =  evalTy btvMap body
            }
        end
  and evalBtvEnv (btvMap:btvMap) (btvEnv:T.btvEnv) =
      BoundTypeVarID.Map.map (evalKind btvMap) btvEnv
  and evalKind (btvMap:btvMap) (T.KIND {tvarKind, eqKind, dynKind, reifyKind, subkind}) =
      T.KIND {tvarKind=evalTvarKind btvMap tvarKind,
              eqKind=eqKind,
              subkind=subkind,
              dynKind=dynKind,
              reifyKind=reifyKind}
  and evalTvarKind btvMap tvarKind =
      case tvarKind of
        T.OCONSTkind tyList =>
        T.OCONSTkind (map (evalTy btvMap) tyList)
      | T.OPRIMkind
          {instances:ty list,
           operators:
           {
            oprimId : OPrimID.id,
            longsymbol : longsymbol,
            keyTyList : ty list,
            match : T.overloadMatch,
            instMap : T.overloadMatch OPrimInstMap.map
           } list
          } =>
        T.OPRIMkind
          {instances = map (evalTy btvMap) instances,
           operators =
           map
             (fn {oprimId, longsymbol, keyTyList, match, instMap} =>
                 {oprimId=oprimId,
                  longsymbol=longsymbol,
                  keyTyList = map (evalTy btvMap) keyTyList,
                  match = evalOverloadMatch btvMap match,
                  instMap = OPrimInstMap.map (evalOverloadMatch btvMap) instMap}
             )
             operators
          }
      | T.UNIV => T.UNIV
      | T.BOXED => T.BOXED
      | T.REC (fields:ty RecordLabel.Map.map) =>
        T.REC (RecordLabel.Map.map (evalTy btvMap) fields)
  and evalDtyKind btvMap dtyKind =
      case dtyKind of
        T.DTY => dtyKind
      | T.OPAQUE {opaqueRep:T.opaqueRep, revealKey:T.revealKey} =>
        T.OPAQUE {opaqueRep = evalOpaqueRep btvMap opaqueRep,
                  revealKey=revealKey}
      | T.BUILTIN bty => dtyKind
  and evalOpaqueRep btvMap opaueRep =
      case opaueRep of
        T.TYCON
          {id : T.typId,
           longsymbol : longsymbol,
           iseq : bool,
           arity : int,
           runtimeTy : BuiltinTypeNames.bty,
           conSet,
           conIDSet,
           extraArgs : ty list,
           dtyKind : T.dtyKind
          } =>
        T.TYCON
          {id = id,
           longsymbol = longsymbol,
           iseq = iseq,
           arity = arity,
           runtimeTy = runtimeTy,
           conSet = conSet,
           conIDSet = conIDSet,
           extraArgs = map (evalTy btvMap) extraArgs,
           dtyKind = evalDtyKind btvMap dtyKind
          }
      | T.TFUNDEF {iseq, arity, polyTy} =>
        T.TFUNDEF {iseq=iseq,
                   arity=arity,
                   polyTy = evalTy btvMap polyTy}

  fun evalTyVar (btvMap:btvMap) ({id, ty, path, opaque}:varInfo) =
      {id=id, path=path, ty=evalTy btvMap ty, opaque=opaque}

  fun applyTys (btvMap:btvMap) (btvEnv:T.btvEnv, instTyList:ty list) : btvMap =
      let
        val btvList = BoundTypeVarID.Map.listKeys btvEnv
        val btvBinds = ListPair.zip (btvList, instTyList)
        val btvMap = 
            foldl
              (fn ((btv,ty), btvMap) =>
                  BoundTypeVarID.Map.insert(btvMap, btv, ty))
              btvMap
              btvBinds
      in
        btvMap
      end
end
end
