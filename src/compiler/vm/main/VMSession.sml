(**
 * a session implementation which communicates with the VM simulator.
 * @copyright (c) 2006, Tohoku University.
 * @author YAMATODANI Kiyoshi
 * @version $Id: VMSession.sml,v 1.13 2006/02/28 16:11:14 kiyoshiy Exp $
 *)
structure VMSession : SESSION =
struct

  (***************************************************************************)

  structure RE = RuntimeErrors
  structure ES = ExecutableSerializer

  (***************************************************************************)

  type InitialParameter =
       {
         VM : VM.VM
       }

  (***************************************************************************)

  fun openSession ({VM, ...} : InitialParameter) =
      {
        execute =
        fn code =>
           let val executable = ES.deserialize code
           in VM.execute (VM, executable) end
           handle exn as RE.Abort => raise SessionTypes.Error exn
                | exn as RE.Interrupted => raise SessionTypes.Error exn
                | RE.InvalidCode message =>
                  raise SessionTypes.Error (Fail message)
                | RE.InvalidStatus message =>
                  raise SessionTypes.Error (Fail message)
                | RE.UnexpectedPrimitiveArguments message =>
                  raise SessionTypes.Error (Fail message)
                | RE.Error message => raise SessionTypes.Error (Fail message)
                | exn => raise SessionTypes.Error (exn),
        close = fn _ => ()
      }

  (***************************************************************************)

end
