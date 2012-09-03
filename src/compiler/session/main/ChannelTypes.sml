(**
 * channel is an abstraction of I/O operation.
 *  Motivation is to provide the same facility of the stream classes in the
 * Java library.
 *  It provides an uniform way of I/O operations on file, socket, and memory
 * buffer, which the SML Basis library lacks.
 *
 * @copyright (c) 2006, Tohoku University.
 * @author YAMATODANI Kiyoshi
 * @version $Id: ChannelTypes.sml,v 1.5 2007/02/19 04:06:09 kiyoshiy Exp $
 *)
structure ChannelTypes =
struct

  (***************************************************************************)

  (** channel type providing output operation on destinations. *)
  type OutputChannel =
       {

         (** output a byte to the channel. *)
         send : Word8.word -> unit,

         (** output bytes to the channel. *)
         sendArray : Word8Array.array -> unit,

         (** output bytes to the channel. *)
         sendVector : Word8Vector.vector -> unit,

         (** flushes bytes remaining in buffer into the stream. *)
         flush : unit -> unit,

         (** close the channel. *)
         close : unit -> unit
       }

  (** channel type providing input operation on sources. *)
  type InputChannel =
       {
         (** get a byte from the channel.
          * @return NONE if the channel reaches the EOF.
          *)
         receive : unit -> Word8.word option,

         (** get bytes from the channel.
          * @params maxBytes
          * @param maxBytes the maximum number of bytes to be read.
          * @return array of bytes obtained from the channel.
          *)
         receiveArray : int -> Word8Array.array,

         (** get bytes from the channel.
          * @params maxBytes
          * @param maxBytes the maximum number of bytes to be read.
          * @return array of bytes obtained from the channel.
          *)
         receiveVector : int -> Word8Vector.vector,

         (** close the channel. *)
         close : unit -> unit,

         (** indicatew whether the source reaches the End Of File.
          * @return true if the channel reaches the EOF.
          *)
         isEOF : unit -> bool
       }

  (***************************************************************************)

end
