(**
 * top level module of smlformat.
 * <p>
 * The tasks of this module are
 * <ul>
 *   <li>parses the source code</li>
 *   <li>generates codes of formatters</li>
 *   <li>outputs codes into a destination stream</li>
 * </ul>
 * </p>
 * @author YAMATODANI Kiyoshi
 * @copyright 2010, Tohoku University.
 * @version $Id: PPGMain.sml,v 1.14 2008/08/10 13:44:01 kiyoshiy Exp $
 *)
structure PPGMain :
  sig
    exception Error of string list
    val main :
        {
          sourceFileName : string,
          sourceStream : TextIO.instream,
          destinationStream : TextIO.outstream,
          withLineDirective : bool
        } -> unit
  end =
struct

  (***************************************************************************)

  structure EQ = ErrorQueue
  structure FG = FormatterGenerator
  structure U = Utility

  (***************************************************************************)

  exception Error of string list

  (***************************************************************************)

  (**
   * get the offset of the end of region.
   * @params region
   * @param region a region gotten from ML-lex.
   * @return offset of the end of the region from the beginning of the source
   *         code
   *)
  fun regionToEndPos (SOME((left, right) : Ast.region)) = SOME(right)
    | regionToEndPos NONE = NONE

  (**
   * adjust the position which ML-lex gives into the correct position 
   * <p>
   *  The 'yypos' generated by ML-lex equals to the actual offset from the
   * start of source code plus 2. (This is a bug of ML-lex ?)
   * </p>
   *)
  fun adjustLexPos lexpos = lexpos - Constants.INITIAL_POS_OF_LEXER

  (****************************************)

  (**
   * generates formatter codes for a declaration.
   * @params formatterEnv (regionOpt, dec)
   * @param formatterEnv the formatterEnv which contains previously defined
   *                 formatters.
   * @param regionOpt option of the region of the dec in the source code.
   * @param dec a declaration
   * @return a pair of
   *   <ul>
   *     <li>an updated formatterEnv</li>
   *     <li>a list of pairs of
   *       <ul>
   *          <li>the position where to insert the generated formatter code.
   *              </li>
   *          <li>the generated code of formatter</li>
   *       </ul>
   *       </li>
   *   </ul>
   *)
  fun generateForDec F (regionOpt, dec) =
      (case dec of
         Ast.DatatypeDec {formatComments = _::_, ...} =>
         let val (codes, F') = FG.generateForDataTypeDec F (regionOpt, dec)
         in (F', [(regionToEndPos regionOpt, codes)]) end

       | Ast.TypeDec {formatComments = _::_, ...} =>
         let val (codes, F') = FG.generateForTypeDec F (regionOpt, dec)
         in (F', [(regionToEndPos regionOpt, codes)]) end

       | Ast.AbstypeDec
         {
           formatComments = formatComments as _::_,
           abstycs,
           withtycs,
           bodyBeginPos,
           body
         } =>
         let
           val datatypeDec =
               Ast.DatatypeDec
               {
                 formatComments = formatComments,
                 datatycs = abstycs,
                 withtycs = withtycs
               }
           val (codes, F') =
               FG.generateForDataTypeDec F (regionOpt, datatypeDec)
         in (F', [(SOME bodyBeginPos, codes)]) end

       | Ast.LocalDec (localDec, globalDec) =>
         let
           val (F', codesForLocalDec) = generateForDec F (NONE, localDec)
           val (F'', codesForGlobalDec) =  generateForDec F' (NONE, globalDec)
           val F''' = F'' (* ToDo : F'' = F + globalDec *)
         in
           (F''', codesForLocalDec @ codesForGlobalDec)
         end

       | Ast.SeqDec decs =>
         foldl
             (fn (dec, (F, codes)) =>
                 let val (F', codes') = generateForDec F (NONE, dec)
                 in (F', codes @ codes')
                 end)
             (F, [])
             decs

       | Ast.StrDec structureBinds =>
         let
           fun getStructureBind (regionOpt, Ast.Strb bind) = (regionOpt, bind)
             | getStructureBind (_, Ast.MarkStrb (bind, region)) =
               getStructureBind (SOME region, bind)
         in
           foldl
               (fn (bind, (F, codes)) =>
                   let
                     val (regionOpt, {def, ...}) =
                         getStructureBind (NONE, bind)
                     val (F', codes') = generateForStructure F (regionOpt, def)
                   in (F', codes @ codes')
                   end)
               (F, [])
               structureBinds
         end

       | Ast.FctDec functorBinds =>
         let
           fun getFunctorBind (regionOpt, Ast.Fctb bind) = (regionOpt, bind)
             | getFunctorBind (_, Ast.MarkFctb (bind, region)) =
               getFunctorBind (SOME region, bind)
         in
           foldl
               (fn (bind, (F, codes)) =>
                   let
                     val (regionOpt, {def, ...}) =
                         getFunctorBind (NONE, bind)
                     val (F', codes') = generateForFunctor F (regionOpt, def)
                   in (F', codes @ codes')
                   end)
               (F, [])
               functorBinds
         end

       | Ast.MarkDec (dec, region) => generateForDec F (SOME region, dec)

       | Ast.ExceptionDec {formatComments = _::_, ...} =>
         let val (codes, F') = FG.generateForExceptionDec F (regionOpt, dec)
         in (F', [(regionToEndPos regionOpt, codes)]) end

       | _ => (F, []))
      handle exn as FG.GenerationError _ => (EQ.add (EQ.Error exn); (F, []))

  (**
   * generates formatter codes for a structure.
   * @params formatterEnv (region, strexp)
   * @param formatterEnv the formatterEnv which contains previously defined
   *                 formatters.
   * @param region the region of the structure expression in the source code.
   * @param strexp the structure expression
   * @return a pair of
   *   <ul>
   *     <li>an updated formatterEnv</li>
   *     <li>a list of pairs of
   *       <ul>
   *          <li>the region of declaration for which a formatter is generated
   *              </li>
   *          <li>the generated code of formatter</li>
   *       </ul>
   *       </li>
   *   </ul>
   *)
  and generateForStructure F (regionOpt, Ast.BaseStr dec) =
      generateForDec F (regionOpt, dec)

    | generateForStructure F (regionOpt, Ast.LetStr(dec, str)) =
      let
        val (F', codesForDec) = generateForDec F (NONE, dec)
        val (F'', codesForStr) = generateForStructure F' (NONE, str)
      in (F'', codesForDec @ codesForStr) end

    | generateForStructure F (_, Ast.MarkStr(strexp, region)) =
      generateForStructure F (SOME region, strexp)

    | generateForStructure F _ = (F, [])

  and generateForFunctor F (regionOpt, Ast.BaseFct {body,...}) =
      generateForStructure F (regionOpt, body)

    | generateForFunctor F (regionOpt, Ast.LetFct(dec, str)) =
      let
        val (F', codesForDec) = generateForDec F (NONE, dec)
        val (F'', codesForFct) = generateForFunctor F' (NONE, str)
      in (F'', codesForDec @ codesForFct) end

    | generateForFunctor F (_, Ast.MarkFct(fctexp, region)) =
      generateForFunctor F (SOME region, fctexp)

    | generateForFunctor F _ = (F, [])

  (****************************************)

  (**
   *  generates a file which contains codes of formatters for the type/datatype
   * defined in the souce file.
   *
   * @params
   *    {sourceFileName, sourceStream, destinationStream, withLineDirective}
   * @param sourceFileName name of the SML source file which contains
   *               type/datatype declarations annotated with format comments.
   * @param sourceStream the stream of SML source code
   * @param destinationStream the stream to which the generated code is emit
   * @param withLineDirective if true, line directives should be inserted in
   *         the result code to point positions in the original source code.
   * @return unit
   *)
  fun main
        {sourceFileName, sourceStream, destinationStream, withLineDirective} =
      let
        (* the all contents of source stream is pulled out here,
         * because the source code is scanned twice in the following process.
         *)
        val sourceCode = TextIO.inputAll sourceStream

        (* parse *)
        val (decs, posToLocation) =
            MLParser.parse (sourceFileName, TextIO.openString sourceCode)
            handle MLParser.ParseError message =>
                   raise Error [message]

        (* generates formatters *)
        val F = BasicFormattersEnv.basicFormattersEnv
        val _ = ErrorQueue.initialize ()
        val (F, codes) =
            (foldl
             (fn(dec, (F, codes)) =>
                let val (F, codes') = generateForDec F (NONE, dec)
                in (F, codes @ codes') end)
             (F, [])
             decs)
        val _ = case ErrorQueue.getAll () of
                  [] => ()
                | errors =>
                  let
                    fun toString
                        (EQ.Error(FG.GenerationError(message, region))) =
                        MLParser.getErrorMessage
                            sourceFileName
                            posToLocation
                            (message, region)
                      | toString (EQ.Error exn) =
                        raise Fail ("BUG: unknown exception:" ^ exnMessage exn)
                      | toString _ = raise Fail "BUG: impossible exception"
                    val messages = map toString errors
                  in raise Error messages end

        local
          (* collect formatters for which the destination tag is specified. *)
          val customPositionCodes =
              foldl
              (fn ((_, codes), accum) =>
                  (List.filter (fn (SOME _, _) => true | _ => false) codes) @
                  accum)
              []
              codes
        in
        (**
         * replaces anchor strings in the text with codes of formatters.
         * @params text
         * @param text a string in which anchor strings may be included
         * @return a new string 
         *)
        fun replaceFormatters text =
            foldl
            (fn ((SOME anchor, code), text) =>
                let val (_, newText) = U.replaceString anchor code text
                in newText end
              | _ => raise Fail "BUG: NONE of anchor text"
            )
            text
            customPositionCodes
        end

        (**
         *  outputs source code in which generated formatters are inserted at
         * appropriate location.
         * @params sourceStream readChars position texts codes
         * @param sourceStream the stream from which source code is read.
         * @param readChars the number of chars which have been read from
         *                   the source stream so far.
         * @param position current position
         * @param texts intermediate result of merge of source code and
         *             generated code. They are in reversed order.
         * @param codes a list of codes of generated formatters
         * @return source code in which generated codes are inserted
         *         at appropriate positions.
         *)
        fun merge sourceStream readChars pos texts =
         fn [] => rev ((TextIO.inputAll sourceStream) :: texts)
          | ((NONE, _) :: _) =>
            raise Fail "BUG: cannot fix the location to insert a code."
          | ((SOME insertPosition, codes)::tail) =>
            let
              val toCopy = (adjustLexPos insertPosition) - readChars
              val input = TextIO.inputN (sourceStream, toCopy)
              (* get pos at the end of input. *)
              val pos as (line, col) =
                  CharVector.foldl
                      (fn (c, (line, col)) =>
                          case c
                           of #"\n" => (line + 1, 1)
                            | _  => (line, col + 1))
                      pos
                      input
              (* This line directive points at the end of input. *)
              val directive =
                  if withLineDirective
                  then 
                    String.concat
                        ["(*#line ", Int.toString line, ".", Int.toString col,
                         " \"", sourceFileName, "\"*)"]
                  else ""
              val generatedCode = 
                  String.concat
                      (U.interleave
                           "\n"
                           (map
                                (fn (_, code) => code)
                                (List.filter
                                     (fn (NONE, _) => true | _ => false)
                                     codes)))
              (* new texts are prepended. they are reversed at last. *)
              val newTexts =
                  directive :: generatedCode :: (input ^ "\n") :: texts
            in
              merge sourceStream (readChars + toCopy) pos newTexts tail
            end

        val merged = merge (TextIO.openString sourceCode) 0 (1, 1) [] codes
        val replaced = map replaceFormatters merged
      in
        app (fn text => TextIO.output (destinationStream, text)) replaced
      end

  (***************************************************************************)

end;
