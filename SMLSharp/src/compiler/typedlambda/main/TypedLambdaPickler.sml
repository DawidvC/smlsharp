(**
 * pickler for typedlambda 
 * @author Liu Bochao
 * @author Huu-Duc Nguyen
 * @version $Id: TypedLambdaPickler.sml,v 1.19 2007/11/09 09:02:01 bochao Exp $
 *)
structure TypedLambdaPickler =
struct
(*
  (***************************************************************************)

  structure P = Pickle
  structure T = Types
  structure TL = TypedLambda
  structure CT = ConstantTerm
  (***************************************************************************)
  
  val loc = NamePickler.loc
  val ty = TypesPickler.ty
  val tyCon = TypesPickler.tyCon
  val id = TypesPickler.id
  val varIdInfo = TypesPickler.varIdInfo
  val valIdent = TypesPickler.valIdent
  val primInfo = TypesPickler.primInfo
  val btvKind = TypesPickler.btvKind
  val btvEnv = TypesPickler.btvEnv
  val constant = ConstantTermPickler.constant
  val callingConvention = AbsynPickler.callingConvention

  val dummyExp = TL.TLCONSTANT {value = CT.INT 0, loc = Loc.noloc}
  val dummyVar = {id = ID.generate (), displayName = "", ty = T.BOUNDVARty 1, kind = T.INTERNAL}
  val dummyDecl = TL.TLVAL {boundVar = dummyVar, boundExp = dummyExp, loc = Loc.noloc}

  val (tlexpFunctions, tlexp) = P.makeNullPu dummyExp
  val (tldeclFunctions, tldecl) = P.makeNullPu dummyDecl

  local
    val newTlexp : TL.tlexp P.pu =
        let
          fun toInt (TL.TLAPPM _) = 0
            | toInt (TL.TLARRAY _) = 1
            | toInt (TL.TLCONSTANT _) = 2
            | toInt (TL.TLCAST _) = 3
            | toInt (TL.TLEXCEPTIONTAG _) = 4
            | toInt (TL.TLEXPORTCALLBACK _) = 5
            | toInt (TL.TLFOREIGNAPPLY _) = 6
            | toInt (TL.TLFNM _) = 7
            | toInt (TL.TLGETFIELD _) = 8
            | toInt (TL.TLHANDLE _) = 9
            | toInt (TL.TLLET _) = 10
            | toInt (TL.TLMODIFY _) = 11
            | toInt (TL.TLPRIMAPPLY _) = 12
            | toInt (TL.TLRECORD _) = 13
            | toInt (TL.TLRAISE _) = 14
            | toInt (TL.TLPOLY _) = 15
            | toInt (TL.TLSELECT _) = 16
            | toInt (TL.TLSETFIELD _) = 17
            | toInt (TL.TLSETTAIL _) = 18
            | toInt (TL.TLSIZEOF _) = 19
            | toInt (TL.TLSWITCH _) = 20
            | toInt (TL.TLTAPP _) = 21
            | toInt (TL.TLVAR _) = 22
            | toInt (TL.TLCOPYARRAY _) = 23

          fun pu_TLAPPM pu = 
            P.con1 
            TL.TLAPPM 
            (fn TL.TLAPPM arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLAPPM in pu_TLAPPM (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             (fn (funExp, funTy, argExpList, loc) => 
              {funExp = funExp, funTy = funTy, argExpList = argExpList, loc = loc},
              fn {funExp = funExp, funTy = funTy, argExpList = argExpList, loc = loc} =>
              (funExp, funTy, argExpList, loc))
             (P.tuple4 (tlexp, ty, P.list tlexp, loc)))
              
          fun pu_TLARRAY pu =
            P.con1
            TL.TLARRAY
            (fn TL.TLARRAY arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLARRY in pu_TLARRAY (typedlambda/main/TypedLambdaPickler)"
            )
            (P.conv
             ((fn (sizeExp, initialValue, elementTy, loc) =>
               {sizeExp = sizeExp, 
                initialValue = initialValue,
                elementTy = elementTy,
                loc = loc}),
              (fn {sizeExp, initialValue, elementTy, loc} => 
               (sizeExp, initialValue, elementTy, loc)))
             (P.tuple4(tlexp, tlexp, ty, loc)))

          fun pu_TLCONSTANT pu =
            P.con1
            TL.TLCONSTANT
            (fn TL.TLCONSTANT arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLCONSTANT in pu_TLCONSTANT (typedlambda/main/TypedLambdaPickler)"
            )
            (P.conv
             ((fn (value,loc) => {value = value, loc = loc}),
              (fn {value, loc} => (value,loc)))
             (P.tuple2(constant,loc)))

          fun pu_TLCAST pu =
            P.con1
            TL.TLCAST
            (fn TL.TLCAST arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLCAST in pu_TLCAST (typedlambda/main/TypedLambdaPickler)"
            )
            (P.conv
             ((fn (exp, targetTy, loc) =>
               {exp = exp,
                targetTy = targetTy,
                loc = loc}),
              (fn {exp, targetTy, loc} => (exp, targetTy, loc)))
             (P.tuple3(tlexp, ty, loc)))

          fun pu_TLEXCEPTIONTAG pu =
            P.con1
            TL.TLEXCEPTIONTAG
            (fn TL.TLEXCEPTIONTAG arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLEXCEPTIONTAG in pu_TLEXCEPTIONTAG (typedlambda/main/TypedLambdaPickler)"
            )
            (P.conv
             ((fn (tagValue, loc) => {tagValue = tagValue, loc = loc},
               (fn {tagValue, loc} => (tagValue,loc))))
             (P.tuple2(GlobalTag.pu_globalTag,loc)))

          fun pu_TLEXPORTCALLBACK pu =
            P.con1 
            TL.TLEXPORTCALLBACK
            (fn TL.TLEXPORTCALLBACK arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLEXPORTCALLBACK in pu_TLEXPORTCALLBACK (typedlambda/main/TypedLambdaPickler)"
            )
            (P.conv
             ((fn (funExp, funTy, loc) =>
               {funExp = funExp, funTy = funTy,loc = loc}),
              (fn {funExp, funTy, loc} =>
               (funExp, funTy, loc)))
             (P.tuple3(tlexp, ty, loc)))

          fun pu_TLFOREIGNAPPLY pu =
            P.con1 
            TL.TLFOREIGNAPPLY
            (fn TL.TLFOREIGNAPPLY arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLFOREIGNAPPLY in pu_TLFOREIGNAPPLY (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (funExp, funTy, argExpList, convention,loc) =>
               {funExp = funExp,
                funTy = funTy,
                argExpList = argExpList, 
                convention = convention,
                loc = loc}),
              (fn {funExp, funTy, argExpList, convention, loc} =>
               (funExp, funTy, argExpList, convention, loc)))
             (P.tuple5(tlexp, ty, P.list tlexp, callingConvention, loc)))

          fun pu_TLFNM pu =
            P.con1 
            TL.TLFNM
            (fn TL.TLFNM arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLFNM in pu_TLFNM (typedlambda/main/TypedLambdaPickler)"
            )
            (P.conv
             ((fn (argVarList, bodyTy, bodyExp, loc) =>
               {argVarList = argVarList, 
                bodyTy = bodyTy, 
                bodyExp = bodyExp,
                loc = loc}),
              (fn {argVarList, bodyTy, bodyExp, loc} =>
               (argVarList, bodyTy, bodyExp, loc)))
             (P.tuple4(P.list varIdInfo, ty, tlexp, loc)))

          fun pu_TLGETFIELD pu =
            P.con1
            TL.TLGETFIELD
            (fn TL.TLGETFIELD arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLGETFIELD in pu_TLGETFIELD (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (arrayExp,  indexExp, elementTy, loc) =>
               {arrayExp = arrayExp, 
                indexExp = indexExp, 
                elementTy = elementTy, 
                loc = loc}),
              (fn {arrayExp, indexExp, elementTy, loc} =>
               (arrayExp,  indexExp, elementTy, loc)))
             (P.tuple4(tlexp,tlexp,ty,loc)))

          fun pu_TLHANDLE pu =
            P.con1
            TL.TLHANDLE
            (fn TL.TLHANDLE arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLHANDLE in pu_TLHANDLE (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv 
             ((fn (exp, exnVar, handler, loc) =>
               {exp = exp, 
                exnVar = exnVar, 
                handler = handler,
                loc = loc}),
              (fn {exp, exnVar, handler, loc} =>
               (exp, exnVar, handler, loc)))
             (P.tuple4(tlexp, varIdInfo, tlexp, loc)))

          fun pu_TLLET pu =
            P.con1
            TL.TLLET
            (fn TL.TLLET arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLLET in pu_TLLET (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (localDeclList, mainExp, loc) =>
               {localDeclList = localDeclList,
                mainExp = mainExp,
                loc = loc}),
              (fn {localDeclList, mainExp, loc} =>
               (localDeclList, mainExp, loc)))
             (P.tuple3(P.list tldecl, tlexp, loc)))
              
          fun pu_TLMODIFY pu =
            P.con1
            TL.TLMODIFY
            (fn TL.TLMODIFY arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLMODIFY in pu_TLMODIFY (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (recordExp, recordTy, label, valueExp, loc) =>
               {recordExp = recordExp,
                recordTy = recordTy,
                label = label,
                valueExp = valueExp,
                loc = loc}),
              (fn {recordExp, recordTy, label, valueExp, loc} =>
               (recordExp, recordTy, label, valueExp, loc)))
             (P.tuple5(tlexp, ty, P.string, tlexp , loc)))

          fun pu_TLPRIMAPPLY pu =
            P.con1
            TL.TLPRIMAPPLY
            (fn TL.TLPRIMAPPLY arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLPRIMAPPLY in pu_TLPRIMAPPLY (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (primInfo, argExpList, loc) =>
               {primInfo = primInfo, 
                argExpList = argExpList,
                loc = loc}),
              (fn {primInfo, argExpList, loc} =>
               (primInfo, argExpList, loc)))
             (P.tuple3(primInfo, P.list tlexp, loc)))
                
          fun pu_TLRECORD pu = 
            P.con1
            TL.TLRECORD
            (fn TL.TLRECORD arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLRECORD in pu_TLRECORD (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (expList, recordTy, isMutable, loc) =>
               {expList = expList, recordTy = recordTy, isMutable = isMutable, loc = loc}),
              (fn {expList, recordTy, isMutable, loc} =>
               (expList, recordTy, isMutable, loc)))
             (P.tuple4(P.list tlexp, ty, P.bool, loc)))
                
          fun pu_TLRAISE pu = 
            P.con1
            TL.TLRAISE
            (fn TL.TLRAISE arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLRAISE in pu_TLRAISE (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (argExp, resultTy, loc) =>
               {argExp = argExp, resultTy = resultTy , loc = loc}),
              (fn {argExp, resultTy , loc} =>
               (argExp, resultTy, loc)))
             (P.tuple3(tlexp, ty, loc)))
               
          fun pu_TLPOLY pu =
            P.con1
            TL.TLPOLY
            (fn TL.TLPOLY arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLPOLY in pu_TLPOLY (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (btvEnv, expTyWithoutTAbs, exp, loc) =>
               {btvEnv = btvEnv, 
                expTyWithoutTAbs = expTyWithoutTAbs,
                exp = exp, 
                loc = loc}),
              (fn {btvEnv, expTyWithoutTAbs, exp, loc} =>
               (btvEnv, expTyWithoutTAbs, exp, loc)))
             (P.tuple4(btvEnv, ty, tlexp, loc)))
                
          fun pu_TLSELECT pu =
            P.con1
            TL.TLSELECT
            (fn TL.TLSELECT arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLSELECT in pu_TLSELECT (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (recordExp, label, recordTy, loc) =>
               {recordExp = recordExp, 
                label = label, 
                recordTy = recordTy,
                loc = loc}),
              (fn {recordExp, label, recordTy, loc} =>
               (recordExp, label, recordTy, loc)))
             (P.tuple4(tlexp,P.string, ty, loc)))

          fun pu_TLSETFIELD pu =
            P.con1
            TL.TLSETFIELD
            (fn TL.TLSETFIELD arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLSETFIELD in pu_TLSETFIELD (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (valueExp, arrayExp, indexExp, elementTy, loc) =>
               {valueExp = valueExp, 
                arrayExp = arrayExp, 
                indexExp = indexExp, 
                elementTy = elementTy, 
                loc = loc}),
              (fn {valueExp, arrayExp, indexExp, elementTy, loc} =>
               (valueExp, arrayExp, indexExp, elementTy, loc)))
             (P.tuple5(tlexp, tlexp, tlexp, ty, loc)))

          fun pu_TLSETTAIL pu =
            P.con1
            TL.TLSETTAIL
            (fn TL.TLSETTAIL arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLSETTAIL in pu_TLSETTAIL (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (consExp, newTailExp, listTy, consRecordTy, tailLabel, loc) =>
               {
                consExp = consExp, 
                newTailExp = newTailExp, 
                listTy = listTy,
                consRecordTy = consRecordTy,
                tailLabel = tailLabel,
                loc = loc
                }),
              (fn {consExp, newTailExp, listTy, consRecordTy, tailLabel, loc} =>
               (consExp, newTailExp, listTy, consRecordTy, tailLabel, loc)
               ))
             (P.tuple6(tlexp, tlexp, ty, ty, P.string, loc)))


          fun pu_TLSIZEOF pu =
            P.con1
            TL.TLSIZEOF
            (fn TL.TLSIZEOF arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLSIZEOF in pu_TLSIZEOF (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (ty, loc) => {ty = ty, loc = loc}),
              (fn {ty, loc} => (ty, loc)))
             (P.tuple2(ty, loc)))

          fun pu_TLSWITCH pu =
            let
              val branch =
                P.conv
                ((fn (constant,exp) => {constant = constant,exp = exp}),
                 (fn {constant, exp} => (constant, exp)))
                (P.tuple2(tlexp, tlexp))
            in
              P.con1
              TL.TLSWITCH 
              (fn TL.TLSWITCH arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLSWITCH in pu_TLSWITCH (typedlambda/main/TypedLambdaPickler)"
               )
              (P.conv
               ((fn (switchExp, expTy, branches, defaultExp, loc) =>
                 {switchExp = switchExp, 
                  expTy = expTy,
                  branches = branches,
                  defaultExp = defaultExp,
                  loc = loc}),
                (fn {switchExp, expTy, branches, defaultExp, loc} =>
                 (switchExp, expTy, branches, defaultExp, loc)))
               (P.tuple5(tlexp, ty, P.list branch, tlexp, loc)))
            end
                
          fun pu_TLTAPP pu =
            P.con1
            TL.TLTAPP
            (fn TL.TLTAPP arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLTAPP in pu_TLTAPP (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (exp, expTy, instTyList, loc) =>
               {exp = exp , expTy = expTy, instTyList = instTyList, loc = loc}),
              (fn {exp, expTy, instTyList, loc} =>
               (exp, expTy, instTyList, loc)))
             (P.tuple4(tlexp, ty, P.list ty, loc)))

          fun pu_TLVAR pu = 
            P.con1
            TL.TLVAR
            (fn TL.TLVAR arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLVAR in pu_TLVAR (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (varInfo, loc) => {varInfo = varInfo, loc = loc}),
              (fn {varInfo, loc} => (varInfo, loc)))
             (P.tuple2(varIdInfo,loc)))

          fun pu_TLCOPYARRAY pu =
            P.con1
            TL.TLCOPYARRAY
            (fn TL.TLCOPYARRAY arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLCOPYARRAY in pu_TLCOPYARRAY (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (srcExp, srcIndexExp, dstExp, dstIndexExp, lengthExp, elementTy, loc) =>
               {srcExp = srcExp, 
                srcIndexExp = srcIndexExp,
                dstExp = dstExp,
                dstIndexExp = dstIndexExp,
                lengthExp = lengthExp,
                elementTy = elementTy, 
                loc = loc}),
              (fn {srcExp, srcIndexExp, dstExp, dstIndexExp, lengthExp, elementTy, loc} =>
                  (srcExp, srcIndexExp, dstExp, dstIndexExp, lengthExp, elementTy, loc)))
             (P.tuple7(tlexp, tlexp, tlexp, tlexp, tlexp, ty, loc)))
        in
          P.data
            (
             toInt,
             [ (* CAUTION: if 'pu_XXXty' is the n-th element of this list,
                * 'toInt XXXty' must return n. *)
              pu_TLAPPM (* 0 *),
              pu_TLARRAY (* 1 *),
              pu_TLCONSTANT (* 2 *),
              pu_TLCAST (* 3 *),
              pu_TLEXCEPTIONTAG (* 4 *),
              pu_TLEXPORTCALLBACK (* 5 *),
              pu_TLFOREIGNAPPLY (* 6 *),
              pu_TLFNM (* 7 *),
              pu_TLGETFIELD (* 8 *),
              pu_TLHANDLE (* 9 *),
              pu_TLLET (* 10 *),
              pu_TLMODIFY (* 11 *),
              pu_TLPRIMAPPLY (* 12 *),
              pu_TLRECORD (* 13 *),
              pu_TLRAISE (* 14 *),
              pu_TLPOLY (* 15 *),
              pu_TLSELECT (* 16 *),
              pu_TLSETFIELD (* 17 *),
              pu_TLSETTAIL (* 18 *),
              pu_TLSIZEOF (* 19 *),
              pu_TLSWITCH (* 20 *),
              pu_TLTAPP (* 21 *),
              pu_TLVAR (* 22 *),
              pu_TLCOPYARRAY (* 23 *)
              ]
             )
        end
    val newTldecl : TL.tldecl P.pu =
        let
          fun toInt (TL.TLVAL _) = 0
            | toInt (TL.TLVALREC _) = 1
            | toInt (TL.TLVALPOLYREC _) = 2
            | toInt (TL.TLVALPOLYREC _) = 2

          fun pu_TLVAL pu =
            P.con1
            TL.TLVAL
            (fn TL.TLVAL arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLVAL in pu_TLVAL (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (boundVar, boundExp, loc) =>
               {boundVar = boundVar, boundExp = boundExp, loc = loc}),
              (fn {boundVar, boundExp, loc} =>
               (boundVar, boundExp, loc)))
             (P.tuple3 (varIdInfo, tlexp, loc)))

          fun pu_TLVALREC pu =
            P.con1
            TL.TLVALREC
            (fn TL.TLVALREC arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLVALREC in pu_TLVALREC (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (recbinds, loc) =>
               let
                 val recbindList = 
                   map (fn (boundVar, boundExp) =>
                        {boundVar = boundVar, boundExp = boundExp})
                   recbinds
               in
                 {recbindList = recbindList, loc = loc}
               end),
              (fn {recbindList, loc} =>
               let
                 val recbinds = 
                   map (fn {boundVar, boundExp} => (boundVar, boundExp))
                   recbindList
               in
                 (recbinds, loc)
               end))
             (P.tuple2 (P.list(P.tuple2(varIdInfo, tlexp)), loc)))

          fun pu_TLVALPOLYREC pu =
            P.con1
            TL.TLVALPOLYREC
            (fn TL.TLVALPOLYREC arg => arg
              | _ => 
                raise 
                  Control.Bug 
                  "non TLVALPOLYREC in pu_TLVALPOLYREC (typedlambda/main/TypedLambdaPickler)"
             )
            (P.conv
             ((fn (btvEnv, recbinds, loc) =>
               let
                 val recbindList = 
                   map (fn (boundVar, boundExp) =>
                        {boundVar = boundVar, boundExp = boundExp})
                   recbinds
               in
                 {btvEnv = btvEnv, 
                  recbindList = recbindList, 
                  loc = loc}
               end),
              (fn {btvEnv, recbindList, loc} =>
               let
                 val recbinds = 
                   map (fn {boundVar, boundExp} => (boundVar, boundExp))
                   recbindList
               in
                 (btvEnv, recbinds, loc)
               end))
             (P.tuple3 (btvEnv, P.list(P.tuple2(varIdInfo, tlexp)), loc)))

        in
          P.data
            (
             toInt,
             [ (* CAUTION: if 'pu_XXXty' is the n-th element of this list,
                * 'toInt XXXty' must return n. *)
              pu_TLVAL, (* 0 *)
              pu_TLVALREC, (* 1 *)
              pu_TLVALPOLYREC (* 2 *)
              ]
             )

        end
  in
    val _ = P.updateNullPu tlexpFunctions newTlexp 
    val _ = P.updateNullPu tldeclFunctions newTldecl 
  end
*)
end